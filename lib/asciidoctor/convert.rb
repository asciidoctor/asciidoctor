# frozen_string_literal: true
module Asciidoctor
  class << self
    # Public: Parse the AsciiDoc source input into an Asciidoctor::Document and
    # convert it to the specified backend format.
    #
    # Accepts input as an IO (or StringIO), String or String Array object. If the
    # input is a File, the object is expected to be opened for reading and is not
    # closed afterwards by this method. Information about the file (filename,
    # directory name, etc) gets assigned to attributes on the Document object.
    #
    # If the :to_file option is true, and the input is a File, the output is
    # written to a file adjacent to the input file, having an extension that
    # corresponds to the backend format. Otherwise, if the :to_file option is
    # specified, the file is written to that file. If :to_file is not an absolute
    # path, it is resolved relative to :to_dir, if given, otherwise the
    # Document#base_dir. If the target directory does not exist, it will not be
    # created unless the :mkdirs option is set to true. If the file cannot be
    # written because the target directory does not exist, or because it falls
    # outside of the Document#base_dir in safe mode, an IOError is raised.
    #
    # If the output is going to be written to a file, the header and footer are
    # included unless specified otherwise (writing to a file implies creating a
    # standalone document). Otherwise, the header and footer are not included by
    # default and the converted result is returned.
    #
    # input   - the String AsciiDoc source filename
    # options - a String, Array or Hash of options to control processing (default: {})
    #           String and Array values are converted into a Hash.
    #           See Asciidoctor::Document#initialize for details about options.
    #
    # Returns the Document object if the converted String is written to a
    # file, otherwise the converted String
    def convert input, options = {}
      (options = options.merge).delete :parse
      to_dir = options.delete :to_dir
      mkdirs = options.delete :mkdirs

      case (to_file = options.delete :to_file)
      when true, nil
        unless (write_to_target = to_dir)
          sibling_path = ::File.absolute_path input.path if ::File === input
        end
        to_file = nil
      when false
        to_file = nil
      when '/dev/null'
        return load input, options
      else
        options[:to_file] = write_to_target = to_file unless (stream_output = to_file.respond_to? :write)
      end

      unless options.key? :standalone
        if sibling_path || write_to_target
          options[:standalone] = options.fetch :header_footer, true
        elsif options.key? :header_footer
          options[:standalone] = options[:header_footer]
        end
      end

      # NOTE outfile may be controlled by document attributes, so resolve outfile after loading
      if sibling_path
        options[:to_dir] = outdir = ::File.dirname sibling_path
      elsif write_to_target
        if to_dir
          if to_file
            options[:to_dir] = ::File.dirname ::File.expand_path to_file, to_dir
          else
            options[:to_dir] = ::File.expand_path to_dir
          end
        elsif to_file
          options[:to_dir] = ::File.dirname ::File.expand_path to_file
        end
      end

      # NOTE :to_dir is always set when outputting to a file
      # NOTE :to_file option only passed if assigned an explicit path
      doc = load input, options

      if sibling_path # write to file in same directory
        outfile = ::File.join outdir, %(#{doc.attributes['docname']}#{doc.outfilesuffix})
        raise ::IOError, %(input file and output file cannot be the same: #{outfile}) if outfile == sibling_path
      elsif write_to_target # write to explicit file or directory
        working_dir = (options.key? :base_dir) ? (::File.expand_path options[:base_dir]) : ::Dir.pwd
        # QUESTION should the jail be the working_dir or doc.base_dir???
        jail = doc.safe >= SafeMode::SAFE ? working_dir : nil
        if to_dir
          outdir = doc.normalize_system_path(to_dir, working_dir, jail, target_name: 'to_dir', recover: false)
          if to_file
            outfile = doc.normalize_system_path(to_file, outdir, nil, target_name: 'to_dir', recover: false)
            # reestablish outdir as the final target directory (in the case to_file had directory segments)
            outdir = ::File.dirname outfile
          else
            outfile = ::File.join outdir, %(#{doc.attributes['docname']}#{doc.outfilesuffix})
          end
        elsif to_file
          outfile = doc.normalize_system_path(to_file, working_dir, jail, target_name: 'to_dir', recover: false)
          # establish outdir as the final target directory (in the case to_file had directory segments)
          outdir = ::File.dirname outfile
        end

        if ::File === input && outfile == (::File.absolute_path input.path)
          raise ::IOError, %(input file and output file cannot be the same: #{outfile})
        end

        if mkdirs
          Helpers.mkdir_p outdir
        else
          # NOTE we intentionally refer to the directory as it was passed to the API
          raise ::IOError, %(target directory does not exist: #{to_dir} (hint: set :mkdirs option)) unless ::File.directory? outdir
        end
      else # write to stream
        outfile = to_file
        outdir = nil
      end

      if outfile && !stream_output
        output = doc.convert 'outfile' => outfile, 'outdir' => outdir
      else
        output = doc.convert
      end

      if outfile
        doc.write output, outfile

        # NOTE document cannot control this behavior if safe >= SafeMode::SERVER
        # NOTE skip if stylesdir is a URI
        if !stream_output && doc.safe < SafeMode::SECURE && (doc.attr? 'linkcss') && (doc.attr? 'copycss') &&
            (doc.basebackend? 'html') && !((stylesdir = (doc.attr 'stylesdir')) && (Helpers.uriish? stylesdir))
          if (stylesheet = doc.attr 'stylesheet')
            if DEFAULT_STYLESHEET_KEYS.include? stylesheet
              copy_asciidoctor_stylesheet = true
            elsif !(Helpers.uriish? stylesheet)
              copy_user_stylesheet = true
            end
          end
          copy_syntax_hl_stylesheet = (syntax_hl = doc.syntax_highlighter) && (syntax_hl.write_stylesheet? doc)
          if copy_asciidoctor_stylesheet || copy_user_stylesheet || copy_syntax_hl_stylesheet
            stylesoutdir = doc.normalize_system_path(stylesdir, outdir, doc.safe >= SafeMode::SAFE ? outdir : nil)
            if mkdirs
              Helpers.mkdir_p stylesoutdir
            else
              raise ::IOError, %(target stylesheet directory does not exist: #{stylesoutdir} (hint: set :mkdirs option)) unless ::File.directory? stylesoutdir
            end

            if copy_asciidoctor_stylesheet
              Stylesheets.instance.write_primary_stylesheet stylesoutdir
            # FIXME should Stylesheets also handle the user stylesheet?
            elsif copy_user_stylesheet
              if (stylesheet_src = doc.attr 'copycss') == '' || stylesheet_src == true
                stylesheet_src = doc.normalize_system_path stylesheet
              else
                # NOTE in this case, copycss is a source location (but cannot be a URI)
                stylesheet_src = doc.normalize_system_path stylesheet_src.to_s
              end
              stylesheet_dest = doc.normalize_system_path stylesheet, stylesoutdir, (doc.safe >= SafeMode::SAFE ? outdir : nil)
              # NOTE don't warn if src can't be read and dest already exists (see #2323)
              if stylesheet_src != stylesheet_dest && (stylesheet_data = doc.read_asset stylesheet_src,
                  warn_on_failure: !(::File.file? stylesheet_dest), label: 'stylesheet')
                if (stylesheet_outdir = ::File.dirname stylesheet_dest) != stylesoutdir && !(::File.directory? stylesheet_outdir)
                  if mkdirs
                    Helpers.mkdir_p stylesheet_outdir
                  else
                    raise ::IOError, %(target stylesheet directory does not exist: #{stylesheet_outdir} (hint: set :mkdirs option))
                  end
                end
                ::File.write stylesheet_dest, stylesheet_data, mode: FILE_WRITE_MODE
              end
            end
            syntax_hl.write_stylesheet doc, stylesoutdir if copy_syntax_hl_stylesheet
          end
        end
        doc
      else
        output
      end
    end

    # Public: Parse the contents of the AsciiDoc source file into an
    # Asciidoctor::Document and convert it to the specified backend format.
    #
    # input   - the String AsciiDoc source filename
    # options - a String, Array or Hash of options to control processing (default: {})
    #           String and Array values are converted into a Hash.
    #           See Asciidoctor::Document#initialize for details about options.
    #
    # Returns the Document object if the converted String is written to a
    # file, otherwise the converted String
    def convert_file filename, options = {}
      ::File.open(filename, FILE_READ_MODE) {|file| convert file, options }
    end

    # Deprecated: Use {Asciidoctor.convert} instead.
    alias render convert

    # Deprecated: Use {Asciidoctor.convert_file} instead.
    alias render_file convert_file
  end
end
