require 'pry-debugger'
require 'potracer'
require 'rmagick'

include Magick

module PsdConverter
  class Converter

    def self.create_all
      self.create_all_jpgs
      self.create_all_svgs
    end

    def self.create_all_jpgs()
      files = Dir['*'].select {|x| x =~ /._*psd/ }
      files.each do |file|
        image = ImageList.new(file)
        file_name = file.gsub(".psd", "")
        image[1].write("new#{file_name}.jpg")
      end
    end

    def self.create_all_svgs
      svgs = self.convert_all_psd_to_svg
      self.combine_svgs(svgs)
      self.destroy_temp_folders
    end

    def self.convert_all_psd_to_svg
      files = Dir['*'].select {|x| x =~ /._*psd/ }
      svgs = []
      files.each do |file|
        tmp_dir = 'psd-svg-'+Date.new.to_s+'-'+rand(9999999999999).to_s
        svgs << %x(mkdir -p #{tmp_dir} && convert #{file} -set dispose Previous -coalesce -delete 0,1 -reverse #{tmp_dir}/%d.pbm; cd #{tmp_dir} && potrace -u 1 -s *.pbm && cat *.svg && rm -rf #{tmp_dir})
      end
      return svgs
    end   

    def self.combine_svgs(svgs)
      counter=1
      svgs.each do |svg|
        files = svg.split(/<?xml version="1.0"/)
        files.shift

        header = ""
        body = ""
        footer = "<\/g><\/svg>"

        files.each do |file|
          header_svg = file.gsub(/\n/," ").scan(/(<svg version=)(.*)(">)/).flatten!.join
          header = header_svg
          body << file.scan(/<path d=\"([^"]+)\"\/>/).flatten!.join("\n\n").insert(0, "<path d=\"").insert(-1, "/\"\/>")
        end
        File.open("svg_#{counter}.svg", "a") { |file| file.write(header + "\n\n"+ body + footer) }
        counter += 1
      end
    end

    def self.destroy_temp_folders
      directories = Dir["*"].select{|x| x =~(/psd-svg/)}
      directories.each do |directory|
        %x[rm -rf #{directory}]
      end
    end
  end
end

PsdConverter::Converter.create_all


