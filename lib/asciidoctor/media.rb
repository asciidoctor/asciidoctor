# frozen_string_literal: true
module Asciidoctor
# A utility class for working with media node.
module Media
  # Private: Mixes the {Media} module as static methods into any class that includes the {Media} module.
  #
  # into - The Class that includes the {Media} module
  #
  # Returns nothing
  private_class_method def self.included into
    into.extend Logging
  end || :included

  def video_uri node
    case node.attr 'poster'
    when 'vimeo'
      unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
        asset_uri_scheme = %(#{asset_uri_scheme}:)
      end
      start_anchor = (node.attr? 'start') ? %(#at=#{node.attr 'start'}) : ''
      delimiter = ['?']
      autoplay_param = (node.option? 'autoplay') ? %(#{delimiter.pop || '&amp;'}autoplay=1) : ''
      loop_param = (node.option? 'loop') ? %(#{delimiter.pop || '&amp;'}loop=1) : ''
      muted_param = (node.option? 'muted') ? %(#{delimiter.pop || '&amp;'}muted=1) : ''
      "#{asset_uri_scheme}//player.vimeo.com/video/#{node.attr 'target'}#{autoplay_param}#{loop_param}#{muted_param}#{start_anchor}"
    when 'youtube'
      unless (asset_uri_scheme = (node.document.attr 'asset-uri-scheme', 'https')).empty?
        asset_uri_scheme = %(#{asset_uri_scheme}:)
      end
      rel_param_val = (node.option? 'related') ? 1 : 0
      # NOTE start and end must be seconds (t parameter allows XmYs where X is minutes and Y is seconds)
      start_param = (node.attr? 'start') ? %(&amp;start=#{node.attr 'start'}) : ''
      end_param = (node.attr? 'end') ? %(&amp;end=#{node.attr 'end'}) : ''
      autoplay_param = (node.option? 'autoplay') ? '&amp;autoplay=1' : ''
      loop_param = (has_loop_param = node.option? 'loop') ? '&amp;loop=1' : ''
      mute_param = (node.option? 'muted') ? '&amp;mute=1' : ''
      controls_param = (node.option? 'nocontrols') ? '&amp;controls=0' : ''
      # cover both ways of controlling fullscreen option
      if node.option? 'nofullscreen'
        fs_param = '&amp;fs=0'
      else
        fs_param = ''
      end
      modest_param = (node.option? 'modest') ? '&amp;modestbranding=1' : ''
      theme_param = (node.attr? 'theme') ? %(&amp;theme=#{node.attr 'theme'}) : ''
      hl_param = (node.attr? 'lang') ? %(&amp;hl=#{node.attr 'lang'}) : ''

      # parse video_id/list_id syntax where list_id (i.e., playlist) is optional
      target, list = (node.attr 'target').split '/', 2
      if (list ||= (node.attr 'list'))
        list_param = %(&amp;list=#{list})
      else
        # parse dynamic playlist syntax: video_id1,video_id2,...
        target, playlist = target.split ',', 2
        if (playlist ||= (node.attr 'playlist'))
          # INFO playlist bar doesn't appear in Firefox unless showinfo=1 and modestbranding=1
          list_param = %(&amp;playlist=#{playlist})
        else
          # NOTE for loop to work, playlist must be specified; use VIDEO_ID if there's no explicit playlist
          list_param = has_loop_param ? %(&amp;playlist=#{target}) : ''
        end
      end
      "#{asset_uri_scheme}//www.youtube.com/embed/#{target}?rel=#{rel_param_val}#{start_param}#{end_param}#{autoplay_param}#{loop_param}#{mute_param}#{controls_param}#{list_param}#{fs_param}#{modest_param}#{theme_param}#{hl_param}"
    else
      start_t = node.attr 'start'
      end_t = node.attr 'end'
      time_anchor = (start_t || end_t) ? %(#t=#{start_t || ''}#{end_t ? ",#{end_t}" : ''}) : ''
      "#{node.media_uri(node.attr 'target')}#{time_anchor}"
    end
  end
end
end
