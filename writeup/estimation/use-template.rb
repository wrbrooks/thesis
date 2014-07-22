#! /usr/bin/ruby

source = "estimation.tex"
destination = "estimation.tex"
template = "template.tex"

estimation = []
proofs = []
body = false
appendix = false

#Read the source file
File.open(source, "r").each_line do |line|
    if (!body and !appendix and line.include?("\\section{Introduction}"))
        body = true
        puts "starting body"
    end

    if body
        if not line == "\n"
            if line.include?("\\section*{Appendix") 
                body = false
                appendix = true
                puts "ending body, beginning appendix"
            else
                estimation << line
            end
        end
    end

    if appendix
        if not line == "\n"
            if line.include?("\\bibliographystyle") 
                appendix = false
                puts "ending appendix"
            else
                proofs << line
            end
        end
    end

end


#Read the template file:
template_contents = []
File.open(template, "r").each_line do |line|
    template_contents << line
end


#Replace the body section in template:
loc = template_contents.index {|s| s.include?("[body]")}
template_contents[loc..loc] = estimation

#Replace the appendix section in template:
loc = template_contents.index {|s| s.include?("[appendix]")}
template_contents[loc..loc] = proofs

#Write the complete result to disk
File.open(destination, "w") do |f|
    template_contents.each {|element| f.write(element)}
end
