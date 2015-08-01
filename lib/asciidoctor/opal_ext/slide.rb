class Slide
  def self.render(node)
    backend = node.document.attributes['backend'] || ''
    templatedir = node.document.attributes['templatedir'] || ''
    node_name = node.node_name || ''

    template = File.read(File.join(templatedir, backend, node_name, ".jade"));

    %x(
          var compiled = jade.compile(#{template}, {pretty: true});
          return compiled({ node: #{node} });
      )

  end
end