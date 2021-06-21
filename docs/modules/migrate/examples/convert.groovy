// This script is provided by melix.
// The source can be found at https://gist.github.com/melix/6020336

@Grab('net.sourceforge.htmlcleaner:htmlcleaner:2.4')
import org.htmlcleaner.*

def src = new File('html').toPath()
def dst = new File('asciidoc').toPath()

def cleaner = new HtmlCleaner()
def props = cleaner.properties
props.translateSpecialEntities = false
def serializer = new SimpleHtmlSerializer(props)

src.toFile().eachFileRecurse { f ->
    def relative = src.relativize(f.toPath())
    def target = dst.resolve(relative)
    if (f.isDirectory()) {
        target.toFile().mkdir()
    } else if (f.name.endsWith('.html')) {
        def tmpHtml = File.createTempFile('clean', 'html')
        println "Converting $relative"
        def result = cleaner.clean(f)
        result.traverse({ tagNode, htmlNode ->
                tagNode?.attributes?.remove 'class'
                if ('td' == tagNode?.name || 'th'==tagNode?.name) {
                    tagNode.name='td'
                    String txt = tagNode.text
                    tagNode.removeAllChildren()
                    tagNode.insertChild(0, new ContentNode(txt))
                }

            true
        } as TagNodeVisitor)
        serializer.writeToFile(
                result, tmpHtml.absolutePath, "utf-8"
        )
        "pandoc -f html -t asciidoc -R -S --normalize -e $tmpHtml -o ${target}.adoc".execute().waitFor()
        tmpHtml.delete()
    }/* else {
        "cp html/$relative $target".execute()
    }*/
}
