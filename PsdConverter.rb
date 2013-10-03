require 'pry-debugger'
require 'potracer'
require 'rmagick'

include Magick

module PsdConverter
  class Tags
    attr_accessor :file, :view, :svg_tag

    def initialize(svg_file)
      @file = svg_file
      @view = {}
    end

    def create_json_for_tags
    end

    def set_view
      # Extract svg view box data
      set_svg_tag 
      view[:width] = self.svg_tag.scan(/width='(\d+)/).flatten![0].to_i
      view[:height] = self.svg_tag.scan(/height='(\d+)/).flatten![0].to_i
      
      view[:translate] = {}
      view[:translate]["x"] = self.svg_tag.scan(/translate\((\d+)/).flatten![0].to_i
      view[:translate]["y"] = self.svg_tag.scan(/(translate\(\d.\d+,)(.*)/).flatten![1].scan(/\d+.\d+/)[0].to_i


      view[:scale] = {}
      view[:scale]["x"] = self.svg_tag.scan(/(scale\()(.*)(\,)/).flatten![1].to_i
      view[:scale]["y"] = self.svg_tag.scan(/(scale\(\d+.\d+,)(.*)(\))/).flatten![1].to_i
    end

    def set_svg_tag
      contents = File.read(file)
      svg = contents.scan(/(<svg version=)(.*)(">)/).flatten!.join.gsub("\"", "'")
      self.svg_tag = svg
    end


  end

  class Image
    attr_accessor :file

    def initialize(psd_file)
      @file = psd_file
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


    # -----Don't really need some of these anymore...----- #
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

# files = Dir["*"].select{|x| x =~ /.psd/}
# files.each do |file|
#   psd = PsdConverter::Image.new(file)
#   psd.create_jpg_and_svg
# end



