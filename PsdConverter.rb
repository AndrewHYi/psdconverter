require 'pry-debugger'
require 'potracer'
require 'rmagick'

include Magick

module PsdConverter
  class Converter
    attr_accessor :file

    def initialize(file)
      @file = file
    end

    def create_jpg_and_svg
      path = self.class.get_file_count
      %x[mkdir -p #{path}]

      to_jpg(path)
      to_svg(path)

      self.class.destroy_temp_folders
      self.class.increase_file_count
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
        body << file.scan(/<path d=\"([^"]+)\"\/>/).flatten!.join("\n\n").insert(0, "<path d=\"").insert(-1, "/\"\/>")
      end

      File.open("#{path}/items.svg", "a") { |file| file.write(header + "\n\n"+ body + footer) }

    end


    # ---------- #
    class << self
      def create_all
        self.create_all_jpgs
        self.create_all_svgs
      end

      def create_all_jpgs
        files = Dir['*'].select {|x| x =~ /._*psd/ }
        files.each do |file|
          path = self.create_directory
          image = ImageList.new(file)
          file_name = file.gsub(".psd", "")
          image[1].write("#{path}/new#{file_name}.jpg")
          self.increase_file_count
        end
      end

      def create_all_svgs
        svgs = self.convert_all_psd_to_svg
        self.combine_svgs(svgs)
        self.destroy_temp_folders
      end

      def convert_all_psd_to_svg
        files = Dir['*'].select {|x| x =~ /._*psd/ }
        svgs = []
        files.each do |file|
          tmp_dir = 'psd-svg-'+Date.new.to_s+'-'+rand(9999999999999).to_s
          svgs << %x(mkdir -p #{tmp_dir} && convert #{file} -set dispose Previous -coalesce -delete 0,1 -reverse #{tmp_dir}/%d.pbm; cd #{tmp_dir} && potrace -u 1 -s *.pbm && cat *.svg && rm -rf #{tmp_dir})
        end
        return svgs
      end   

      def combine_svgs(svgs)
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

      def create_directory
        path = self.get_file_count
        %x[mkdir "#{path}"]
        return path
      end

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
end

# PsdConverter::Converter.create_all
files = Dir["*"].select{|x| x =~ /.psd/}
files.each do |file|
  psd = PsdConverter::Converter.new(file)
  psd.create_jpg_and_svg
end



