# =============================================================================
# create_gallery.rb -- create html gallery of chifig examples
#
# Copyright
#
# LICENSE
# =============================================================================

#`rm *.html *.png`

thisdir = File.dirname(File.expand_path(__FILE__))
docdir = File.dirname(thisdir)
exampledir = File.join(docdir, 'examples')

density = 300
size = 500

s = %Q{
<html>
<head>
<style>
td \{
    height: #{size}px;
    vertical-align: center;
    padding: 10px;
\}
</style>
</head>
<body><table>
}
geom = "#{size}x#{size}"

Dir.glob(File.join(exampledir, '*.ps')).each do |pspath|
    test = File.basename(pspath, '.ps')
    epsipath = File.basename(thisdir, test+'.epsi')
    `ps2epsi #{pspath} #{epsipath}`
    pngbase = test+'.png'
    pngpath = File.join(thisdir, pngbase)
    `convert -density #{density} -geometry #{geom} #{epsipath} #{pngpath}`
    File.delete(epsipath)
    imgel = "<img src=\"#{pngbase}\">"
    s << "<tr>\n<td>#{imgel}</td>\n"
    path = "#{test}_dsl.html"
    File.open(path, "w") do |fi|
        fi.write("<html>\n<body>\n#{imgel}<br/>\n<pre>\n")
        File.open(File.join(exampledir, test+'.in'), "r") {|f| fi.write(f.read)}
        fi.write("\n</pre>\n</body>\n</html>")
    end
    s << "<td><a href=\"#{path}\">DSL</a><br/>"
    path = "#{test}_json.html"
    File.open(path, "w") do |fi|
        fi.write("<html>\n<body>\n#{imgel}<br/>\n<pre>\n")
        File.open(File.join(exampledir, test+'.json'), "r") {|f| fi.write(f.read)}
        fi.write("\n</pre>\n</body>\n</html>")
    end
    s << "<a href=\"#{path}\">JSON</a></td>\n"
end
s << "</table>\n</body>\n</html>"
File.open('index.html', 'w') {|f| f.write(s)}
