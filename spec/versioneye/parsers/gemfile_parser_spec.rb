require 'spec_helper'

describe GemfileParser do
  
  describe "helper functions" do
    let(:parser){ GemfilelockParser.new }

    describe "strip_platform_quotes" do
      it "returns non-matching strings untouched" do
        expect( parser.strip_platform_exts('1.0.0')   ).to eq('1.0.0')
        expect( parser.strip_platform_exts('1.0-abc') ).to eq('1.0-abc')
        expect( parser.strip_platform_exts('1.0-a-b') ).to eq('1.0-a-b')
      end

      it "filters out known platform extensions" do
        expect( parser.strip_platform_exts('1.0-x64')       ).to eq('1.0')
        expect( parser.strip_platform_exts('1.0-a-x86')     ).to eq('1.0-a')
        expect( parser.strip_platform_exts('1.0-java')      ).to eq('1.0')
        expect( parser.strip_platform_exts('1.0-java-b-c')  ).to eq('1.0-b-c')
        expect( parser.strip_platform_exts('1.0-mingw32')   ).to eq('1.0')
      end
    end
  end

  describe "parse" do

    def fetch_by_name(dependencies, name)
      dependencies.each do |dep|
        return dep if dep.name.eql? name
      end
    end

    it "parse from https the file correctly" do
      parser = GemfileParser.new
      project = parser.parse("https://s3.amazonaws.com/veye_test_env/Gemfile")
      project.should_not be_nil
    end

    it "parse from http the file correctly" do
      product1 = ProductFactory.create_for_gemfile("execjs", "1.4.0")
      product1.versions.push( Version.new({version: "1.3.0"}) )
      product1.save

      product2 = ProductFactory.create_for_gemfile("jquery-rails", "1.0.0")
      product2.save

      product3 = ProductFactory.create_for_gemfile("therubyracer", "0.11.3")
      product3.versions.push( Version.new({version: "0.10.1"}) )
      product3.save

      product4 = ProductFactory.create_for_gemfile("will_paginate", "4.0.3")
      product4.versions.push( Version.new({version: "3.0.3"}) )
      product4.save

      product5 = ProductFactory.create_for_gemfile("gravatar_image_tag", "1.1.6")
      product5.versions.push( Version.new({version: "1.1.3"}) )
      product5.save

      product6 = ProductFactory.create_for_gemfile("tire", "3.2.5")
      product6.save

      product7 = ProductFactory.create_for_gemfile("sass-rails", "3.3.9")
      product7.versions.push( Version.new({version: "3.2.5"}) )
      product7.versions.push( Version.new({version: "3.2.9"}) )
      product7.save

      product8 = ProductFactory.create_for_gemfile("sassy", "3.3.9")
      product8.versions.push( Version.new({version: "3.2.5"}) )
      product8.versions.push( Version.new({version: "3.2.9"}) )
      product8.save

      product9 = ProductFactory.create_for_gemfile("cucumber-rails", "1.0.0")
      product9.save

      product10 = ProductFactory.create_for_gemfile("fastercsv", "1.0.0")
      product10.save

      product11 = ProductFactory.create_for_gemfile("guard-livereload", "1.0.0")
      product11.save

      product12 = ProductFactory.create_for_gemfile("copycopter_client", "1.0.0")
      product12.save

      product13 = ProductFactory.create_for_gemfile("govkit", "1.0.0")
      product13.save

      product14 = ProductFactory.create_for_gemfile("libnotify", "1.0.0")
      product14.save

      product15 = ProductFactory.create_for_gemfile("growl", "3.3.3")
      product15.save


      parser  = GemfileParser.new
      project = parser.parse("http://s3.amazonaws.com/veye_test_env/Gemfile")
      project.should_not be_nil
      project.dependencies.size.should eql(15)

      dep_1 = fetch_by_name project.dependencies, "rails"
      dep_1.name.should eql("rails")
      dep_1.version_requested.should eql("3.2.6")
      dep_1.comperator.should eql("=")
      expect( dep_1.language ).to eql(Product::A_LANGUAGE_RUBY)

      dep_2 = fetch_by_name project.dependencies, "jquery-rails"
      dep_2.name.should eql("jquery-rails")
      dep_2.version_requested.should eql("1.0.0")
      dep_2.version_current.should eql("1.0.0")
      dep_2.comperator.should eql("=")
      expect( dep_2.language ).to eql(Product::A_LANGUAGE_RUBY)

      dep_3 = fetch_by_name project.dependencies, "execjs"
      dep_3.name.should eql("execjs")
      dep_3.version_requested.should eql("1.3.0")
      dep_3.version_current.should eql("1.4.0")
      dep_3.version_label.should eql("1.4.0")
      dep_3.comperator.should eql("<")
      expect( dep_3.language ).to eql(Product::A_LANGUAGE_RUBY)

      dep_4 = fetch_by_name project.dependencies, "therubyracer"
      dep_4.name.should eql("therubyracer")
      dep_4.version_requested.should eql("0.11.3")
      dep_4.version_current.should eql("0.11.3")
      dep_4.version_label.should eql("0.10.1")
      dep_4.comperator.should eql(">")
      expect( dep_4.language ).to eql(Product::A_LANGUAGE_RUBY)

      dep_5 = fetch_by_name project.dependencies, "will_paginate"
      dep_5.name.should eql("will_paginate")
      dep_5.version_requested.should eql("3.0.3")
      dep_5.version_current.should eql("4.0.3")
      dep_5.version_label.should eql("3.0.3")
      dep_5.comperator.should eql("<=")

      dep_6 = fetch_by_name project.dependencies, "gravatar_image_tag"
      dep_6.name.should eql("gravatar_image_tag")
      dep_6.version_requested.should eql("1.1.6")
      dep_6.version_current.should eql("1.1.6")
      dep_6.version_label.should eql("1.1.3")
      dep_6.comperator.should eql(">=")
      dep_6.release.should_not be_nil
      dep_6.release.should be_truthy

      dep_7 = fetch_by_name project.dependencies, "sassy"
      dep_7.name.should eql("sassy")
      dep_7.version_requested.should eql("3.2.9")
      dep_7.version_current.should eql("3.3.9")
      dep_7.version_label.should eql("3.2.0")
      dep_7.comperator.should eql("~>")

      dep_8 = fetch_by_name project.dependencies, "sass-rails"
      dep_8.name.should eql("sass-rails")
      dep_8.version_requested.should eql("3.3.9")
      dep_8.version_current.should eql("3.3.9")
      dep_8.comperator.should eql("~>")
      dep_8.outdated.should be_falsey

      dep_9 = fetch_by_name project.dependencies, "cucumber-rails"
      dep_9.name.should eql("cucumber-rails")
      dep_9.version_requested.should eql("1.0.0")
      dep_9.version_current.should eql("1.0.0")
      dep_9.comperator.should eql("=")

      dep_10 = fetch_by_name project.dependencies, "fastercsv"
      dep_10.name.should eql("fastercsv")
      dep_10.version_requested.should eql("1.0.0")
      dep_10.version_current.should eql("1.0.0")
      dep_10.comperator.should eql("=")

      dep_11 = fetch_by_name project.dependencies, "guard-livereload"
      dep_11.name.should eql("guard-livereload")
      dep_11.version_requested.should eql("1.0.0")
      dep_11.version_current.should eql("1.0.0")
      dep_11.comperator.should eql("=")

      dep_12 = fetch_by_name project.dependencies, "copycopter_client"
      dep_12.name.should eql("copycopter_client")
      dep_12.version_requested.should eql("GIT")
      dep_12.version_current.should eql("1.0.0")
      dep_12.comperator.should eql("=")

      dep_13 = fetch_by_name project.dependencies, "govkit"
      dep_13.name.should eql("govkit")
      dep_13.version_requested.should eql("PATH")
      dep_13.version_current.should eql("1.0.0")
      dep_13.comperator.should eql("=")

      dep_15 = fetch_by_name project.dependencies, "libnotify"
      dep_15.name.should eql("libnotify")
      dep_15.version_requested.should eql("1.0.0")
      dep_15.version_current.should eql("1.0.0")
      dep_15.comperator.should eql("=")

      dep_16 = fetch_by_name project.dependencies, "growl"
      dep_16.name.should eql("growl")
      dep_16.version_requested.should eql("3.3.3")
      dep_16.version_current.should eql("3.3.3")
      dep_16.comperator.should eql("=")
    end
  end


  describe "fixes for issues" do
    let(:parser){ GemfileParser.new }

    let(:product1){
      FactoryGirl.create(
        :product_with_versions,
        prod_key: 'actioncable',
        name: 'actioncable',
        prod_type: Project::A_TYPE_RUBYGEMS,
        language: Product::A_LANGUAGE_RUBY,
        version: '5.1'
      )
    }
    
    let(:product2){
      FactoryGirl.create(
        :product_with_versions,
        prod_key: 'actionsupport',
        name: 'actionsupport',
        prod_type: Project::A_TYPE_RUBYGEMS,
        language: Product::A_LANGUAGE_RUBY,
        version: '5.2'
      )
    
    }

    let(:project_text){
      %Q{
        source "https://rubygems.org/"
        gem "actioncable", "5.1-mingw32"
        gem "actionsupport", "5.2"
      }
    }
    
    it "removes platform extensions #issue53 " do
      product1.versions << FactoryGirl.build(:product_version, version: '5.1')
      product1.save
      product2.versions << FactoryGirl.build(:product_version, version: '5.2')
      product2.save
      
      proj = parser.parse_content(project_text)
      expect(proj).to_not be_nil
      expect(proj.projectdependencies.size ).to eq(2)

      dep1 = proj.dependencies[0]

      expect( dep1.name ).to eq(product1[:name])
      expect( dep1.version_requested ).to eq(product1[:version])
      expect( dep1.comperator ).to eq('=')

      dep2 = proj.dependencies[1]
      expect( dep2.name ).to eq( product2[:name] )
      expect( dep2.version_requested ).to eq(product2[:version])
      expect( dep2.comperator ).to eq('=')
    end
   
  end
end
