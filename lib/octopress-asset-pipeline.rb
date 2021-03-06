require 'octopress'
require 'octopress-ink'
require 'octopress-asset-pipeline/version'

module Octopress
  module AssetPipeline

    autoload :Asset,                'octopress-asset-pipeline/assets/asset'
    autoload :Css,                  'octopress-asset-pipeline/assets/css'
    autoload :Sass,                 'octopress-asset-pipeline/assets/sass'
    autoload :Javascript,           'octopress-asset-pipeline/assets/javascript'
    autoload :Coffeescript,         'octopress-asset-pipeline/assets/coffeescript'

    class Plugin < Ink::Plugin
      def register
        reset
        # Tell Jekyll to read static files and pages
        # This is necessary when Jekyll isn't being asked to build a site,
        # like when a user runs the list command to list assets
        #
        if Octopress::Docs.enabled?
          add_docs
        end
        if Octopress::Ink.enabled?
          add_files
        end
      end

      def add_files
        if Octopress.site.pages.empty? && Octopress.site.posts.empty?
          Octopress.site.read_directories 
        end

        add_static_files
        add_page_files
        add_stylesheets
        add_javascripts
      end

      def config(*args)
        @config ||= begin
          c = Ink.configuration['asset_pipeline']

          # Deprecation warning - remove in 2.1
          if c['javascripts_dir']
            warn('Deprecation Warning:'.yellow + ' Asset_pipeline configuration key `javascripts_dir` has been renamed to `javascripts_source`. Please update your configuration.')
            c['javascripts_source'] = c.delete('javascripts_dir')
          end
          
          if c['stylesheets_dir']
            warn('Deprecation Warning:'.yellow + ' Asset_pipeline configuration key `stylesheets_dir` has been renamed to `stylesheets_source`. Please update your configuration.')
            c['stylesheets_source'] = c.delete('stylesheets_dir')
          end

          {
            'stylesheets_source' => ['stylesheets', 'css'],
            'javascripts_source' => ['javascripts', 'js']
          }.merge(c).merge({ 'disable' => {} })
        end
      end

      private

      def asset_dirs
        [config['stylesheets_source'], config['javascripts_source']].flatten
      end

      def combine_css
        config['combine_css']
      end

      def combine_js
        config['combine_js']
      end

      def add_stylesheets
        if !combine_css
          # Add tags for {% css_asset_tag %}
          stylesheets.each { |f| Ink::Plugins.add_css_tag(f.tag) }
          @css.clear
        end
      end

      def add_javascripts
        if !combine_js
          # Add tags for {% js_asset_tag %}
          javascripts.each { |f| Ink::Plugins.add_js_tag(f.tag) }
          @js.clear
          @coffee.clear
        end
      end

      def sort(files, config)
        sorted = []
        config.each do |item|
          files.each do |file|
            sorted << files.delete(file) if file.path.to_s.include? item
          end
        end

        sorted.concat files
      end

      # Finds css and js files files registered by Jekyll
      #
      def add_static_files
        find_static_assets(asset_dirs, '.js', '.css').each do |f|
          if File.extname(f.path) == '.js'
            @js << Javascript.new(self, f)
            Octopress.site.static_files.delete(f) if combine_js
          elsif File.extname(f.path) == '.css'
            @css << Css.new(self, f)
            Octopress.site.static_files.delete(f) if combine_css
          end
        end
      end

      # Finds Sass and Coffeescript files files registered by Jekyll
      #
      def add_page_files
        find_page_assets(asset_dirs, '.scss', '.sass', '.coffee', '.js', '.css').each do |f|
          if f.ext =~ /\.coffee$/ 
            @coffee << Coffeescript.new(self, f)
            Octopress.site.pages.delete(f) if combine_js
          elsif f.ext =~ /\.s[ca]ss/ 
            @sass << Sass.new(self, f)
            Octopress.site.pages.delete(f) if combine_css
          elsif f.ext =~ /\.css/ 
            @css << Css.new(self, f)
            Octopress.site.pages.delete(f) if combine_css
          elsif f.ext =~ /\.js/ 
            @js << Javascript.new(self, f)
            Octopress.site.pages.delete(f) if combine_js
          end
        end
      end

      def find_static_assets(dirs, *extensions)
        assets = Octopress.site.static_files.dup.sort_by(&:path)
        find_assets(assets, dirs, extensions)
      end

      def find_page_assets(dirs, *extensions)
        assets = Octopress.site.pages.dup.sort_by(&:path)
        find_assets(assets, dirs, extensions)
      end

      def find_assets(assets, dirs, extensions)
        assets.select do |f| 
          if extensions.include?(File.extname(f.path))
            path = f.path.sub(File.join(Octopress.site.source, ''), '')
            in_dir?(path, dirs)
          end
        end
      end

      def in_dir?(file, *dirs)
        dirs.flatten.select do |d| 
          file.match(/^#{d}\//) 
        end.size > 0
      end
    end
  end
end

Octopress::Ink.register_plugin(Octopress::AssetPipeline::Plugin, {
  name:          "Octopress Asset Pipeline",
  gem:           "octopress-asset-pipeline",
  path:          File.expand_path(File.join(File.dirname(__FILE__), "../")),
  version:       Octopress::AssetPipeline::VERSION,
  description:   "Combine and compress Stylesheets and Javascripts into a single fingerprinted file.",
  source_url:    "https://github.com/octopress/asset-pipeline",
  local: true
})
