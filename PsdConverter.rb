require 'pry-debugger'
require 'potracer'
require 'rmagick'
require 'execjs'

include Magick

module PsdConverter
  class Image
    attr_accessor :file

    def initialize(psd_file)
      @file = psd_file
    end

    def self.convert_all_psds
      files = Dir["*"].select{|x| x =~ /.psd/}
      files.each do |file|
        psd = PsdConverter::Image.new(file)
        psd.create_jpg_svg_json
      end
    end

    def create_jpg_svg_json
      path = get_file_count
      %x[mkdir -p #{path}]

      to_jpg(path)
      to_svg(path)
      create_json_tags(path)

      destroy_temp_folders
      increase_file_count
    end

    def create_json_tags(path)
      ctx = V8::Context.new
      tags = File.read("lib/extractjsons.js")
      ctx['rubySvg'] = File.read("#{path}/items.svg")
      File.open("#{path}/tags.json", 'w') { |f| f.write(ctx.eval(tags))}
    end

    def to_jpg(path)
      image = ImageList.new(file)
      image[1].write("#{path}/outfit.jpg")
    end

    def to_svg(path)
      svg = ""
      tmp_dir = 'psd-svg-'+Date.new.to_s+'-'+rand(9999999999999).to_s
      svg << %x(mkdir -p #{tmp_dir} && convert #{file} -set dispose Previous -coalesce -delete 0,1 -reverse #{tmp_dir}/%d.pbm; cd #{tmp_dir} && potrace -u 1 -s *.pbm && cat *.svg && rm -rf #{tmp_dir})
      
      files = svg.split(/<?xml version="1.0"/)
      files.shift

      header = ""
      body = ""
      footer = "<\/g><\/svg>"

      files.each do |file|
        header_svg = file.gsub(/\n/," ").scan(/(<svg version=)(.*)(">)/).flatten!.join
        header = header_svg
        body << file.scan(/<path d=\"([^"]+)\"\/>/).flatten!.join("\n\n").insert(0, "<path d=\"").insert(-1, "/\"\/>\n")
      end

      File.open("#{path}/items.svg", "a") { |file| file.write(header + "\n\n"+ body + footer) }

    end

    private
    def destroy_temp_folders
      directories = Dir["*"].select{|x| x =~(/psd-svg/)}
      directories.each do |directory|
        %x[rm -rf #{directory}]
      end
    end

    def increase_file_count
      file = YAML::load_file('files.yaml')
      file["files"]["count"] += 1
      File.write('files.yaml', file.to_yaml)
    end

    def get_file_count
      file = YAML::load_file('files.yaml')
      file["files"]["count"]
    end
  end
end

PsdConverter::Image.convert_all_psds



