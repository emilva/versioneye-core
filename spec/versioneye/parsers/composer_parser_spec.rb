require 'spec_helper'

describe ComposerParser do
  let(:parser){ ComposerParser.new }
  let(:test_file_url ){ "https://s3.amazonaws.com/veye_test_env/composer.json" }

  let(:product_01){ ProductFactory.create_for_composer("symfony/symfony", "2.0.7") }
  let(:product_23){ ProductFactory.create_for_bower("bootstrap", "3.3") }
  let(:product_24){ ProductFactory.create_for_npm("request", "1.0.0") }

  let(:dep1){
    Projectdependency.new(
      language: Product::A_LANGUAGE_PHP,
      prod_key: 'symfony/symfony',
      name: 'symfony/symfony'
    )
  }

  describe 'parse_requested_version' do
    before do
      product_01.versions << Version.new(version: '0.1.2')
      product_01.versions << Version.new(version: '0.9')
      product_01.versions << Version.new(version: '1.0.0')
      product_01.versions << Version.new(version: '2.0.7')
      product_01.versions << Version.new(version: '2.2.9')
      product_01.versions << Version.new(version: '3.0.0')
      product_01.versions << Version.new(version: '3.0.1')
      product_01.save
    end

    it 'resolves correctly caret version `^0.1`' do
      parser.parse_requested_version('^0.1', dep1, product_01)
      expect(dep1[:comperator]).to eq('^')
      expect(dep1[:version_label]).to eq('^0.1')
      expect(dep1[:version_requested]).to eq('0.1.2')
    end

    it 'resolves correctly caret version `^0.1.0`' do
      parser.parse_requested_version('^0.1.0', dep1, product_01)
      expect(dep1[:comperator]).to eq('^')
      expect(dep1[:version_label]).to eq('^0.1.0')
      expect(dep1[:version_requested]).to eq('0.1.2')
    end

    it 'resolves correctly caret version `^2.0.7`' do
      parser.parse_requested_version('^2.0.7', dep1, product_01)

      expect(dep1[:comperator]).to eq('^')
      expect(dep1[:version_label]).to eq('^2.0.7')
      expect(dep1[:version_requested]).to eq('2.2.9')
    end
  end

  describe 'fetch_product_for' do
    before do
      product_01.save
      product_23.save
      product_24.save
    end

    it "returns correct Composer product" do
      prod = parser.fetch_product_for 'symfony/symfony'

      expect( prod ).not_to be_nil
      expect( prod[:language] ).to  eq(product_01[:language])
      expect( prod[:prod_key] ).to  eq(product_01[:prod_key])
      expect( prod[:name] ).to      eq(product_01[:name])
    end

    it "returns correct Bower product" do
      prod = parser.fetch_product_for 'bower-asset/bootstrap'

      expect( prod ).not_to be_nil
      expect( prod[:language] ).to  eq(product_23[:language])
      expect( prod[:prod_key] ).to  eq(product_23[:prod_key])
      expect( prod[:name] ).to      eq(product_23[:name])
    end

    it "returns correct NPM product" do
      prod = parser.fetch_product_for 'npm-asset/request'

      expect( prod ).not_to be_nil
      expect( prod[:language] ).to  eq(product_24[:language])
      expect( prod[:prod_key] ).to  eq(product_24[:prod_key])
      expect( prod[:name] ).to      eq(product_24[:name])
    end

  end

  describe 'parse_content' do

    it 'parses the content' do
      cp = CommonParser.new
      response = cp.fetch_response test_file_url
      project = parser.parse_content response.body

      expect( project ).not_to be_nil
    end

  end

  describe "parse" do

    def fetch_by_name(dependencies, name)
      dependencies.each do |dep|
        return dep if dep.name.eql? name
      end
    end

    it "parse from https the file correctly" do
      parser  = ComposerParser.new
      project = parser.parse(test_file_url)
      expect( project ).not_to be_nil
    end

    it "parse from http the file correctly" do
      product_01.versions << Version.new({ :version => "2.0.7-dev" })
      product_01.save

      product_02 = ProductFactory.create_for_composer("symfony/doctrine-bundle", "2.0.7")
      product_02.save

      product_03 = ProductFactory.create_for_composer("symfony/process", "2.0.7")
      product_03.versions.push( Version.new({ :version => "2.0.6" }) )
      product_03.versions.push( Version.new({ :version => "dev-master" }) )
      product_03.save

      product_04 = ProductFactory.create_for_composer("symfony/browser-kit", "2.0.7")
      product_04.versions.push( Version.new({ :version => "2.0.6" }) )
      product_04.save

      product_05 = ProductFactory.create_for_composer("symfony/security-bundle", "2.0.7")
      product_05.versions.push( Version.new({ :version => "2.0.6" }) )
      product_05.save

      product_06 = ProductFactory.create_for_composer("symfony/locale", "2.0.7")
      product_06.versions.push( Version.new({ :version => "2.0.8" }) )
      product_06.save

      product_07 = ProductFactory.create_for_composer("symfony/yaml", "2.0.8")
      product_07.versions.push( Version.new({ :version => "2.0.7" }) )
      product_07.save

      product_08 = ProductFactory.create_for_composer("symfony/http-kernel", "2.0.7")
      product_08.versions.push( Version.new({ :version => "2.0.6" }) )
      product_08.save

      product_09 = ProductFactory.create_for_composer("twig/twig", "2.0.0")
      product_09.versions.push( Version.new({ :version => "1.9.0" }) )
      product_09.versions.push( Version.new({ :version => "1.9.1" }) )
      product_09.versions.push( Version.new({ :version => "1.9.9" }) )
      product_09.save

      product_10 = ProductFactory.create_for_composer("doctrine/common", "2.4")
      product_10.versions.push( Version.new({ :version => "2.2" }) )
      product_10.versions.push( Version.new({ :version => "2.3" }) )
      product_10.versions.push( Version.new({ :version => "2.1" }) )
      product_10.save

      product_11 = ProductFactory.create_for_composer("symfony/console", "2.0.10")
      product_11.versions.push( Version.new({ :version => "2.0.0"       }) )
      product_11.versions.push( Version.new({ :version => "2.0.6"       }) )
      product_11.versions.push( Version.new({ :version => "2.0.7"       }) )
      product_11.versions.push( Version.new({ :version => "2.2.0-BETA2" }) )
      product_11.save

      product_12 = ProductFactory.create_for_composer("symfony/translation", "2.2.x-dev")
      product_12.versions.push( Version.new({ :version => "2.0.0"       }) )
      product_12.versions.push( Version.new({ :version => "2.2.1"       }) )
      product_12.versions.push( Version.new({ :version => "2.2.0-alpha" }) )
      product_12.versions.push( Version.new({ :version => "2.2.0-BETA2" }) )
      product_12.save

      product_13 = ProductFactory.create_for_composer("symfony/filesystem", "2.2.x-dev")
      product_13.versions.push( Version.new({ :version => "2.2.1"       }) )
      product_13.versions.push( Version.new({ :version => "2.2.0-BETA2" }) )
      product_13.save

      product_14 = ProductFactory.create_for_composer("symfony/stopwatch", "2.2.x-dev")
      product_14.versions.push( Version.new({ :version => "2.2.1"       }) )
      product_14.save

      product_16 = ProductFactory.create_for_composer("symfony/finder", "2.2.1")
      product_16.versions.push( Version.new({ :version => "2.2.0"       }) )
      product_16.save

      product_17 = ProductFactory.create_for_composer("symfony/config", "3.0.0")
      product_17.versions.push( Version.new({ :version => "2.2.1"       }) )
      product_17.versions.push( Version.new({ :version => "2.2.2"       }) )
      product_17.versions.push( Version.new({ :version => "2.2.4"       }) )
      product_17.versions.push( Version.new({ :version => "2.3.1"       }) )
      product_17.versions.push( Version.new({ :version => "3.0.0"       }) )
      product_17.save

      product_18 = ProductFactory.create_for_composer("symfony/http-foundation", "1.0.0")
      product_18.versions.push( Version.new({ :version => "2.0.0"       }) )
      product_18.versions.push( Version.new({ :version => "2.1.0"       }) )
      product_18.versions.push( Version.new({ :version => "2.2.0"       }) )
      product_18.versions.push( Version.new({ :version => "2.3.x-dev"   }) )
      product_18.versions.push( Version.new({ :version => "dev-master"  }) )
      product_18.save

      product_19 = ProductFactory.create_for_composer("symfony/http-kernel_2", "1.0.0")
      product_19.versions.push( Version.new({ :version => "2.0.0"       }) )
      product_19.versions.push( Version.new({ :version => "2.1.0"       }) )
      product_19.versions.push( Version.new({ :version => "2.2.0"       }) )
      product_19.versions.push( Version.new({ :version => "2.3-dev"     }) )
      product_19.versions.push( Version.new({ :version => "2.4-dev"     }) )
      product_19.versions.push( Version.new({ :version => "dev-master"  }) )
      product_19.save

      product_20 = ProductFactory.create_for_composer("phpunit/phpunit", "3.7.29")
      product_20.versions.push( Version.new({ :version => "3.7.29"      }) )
      product_20.versions.push( Version.new({ :version => "3.1.0"       }) )
      product_20.versions.push( Version.new({ :version => "3.0.0"       }) )
      product_20.versions.push( Version.new({ :version => "2.3.0"       }) )
      product_20.versions.push( Version.new({ :version => "2.4-dev"     }) )
      product_20.versions.push( Version.new({ :version => "dev-master"  }) )
      product_20.save

      product_21 = ProductFactory.create_for_composer("yiisoft/jquery", "2.1.0")
      product_21.versions.push( Version.new({ :version => "2.0.0"      }) )
      product_21.versions.push( Version.new({ :version => "1.1.0"       }) )
      product_21.save

      product_22 = ProductFactory.create_for_composer("phpuno/phpuno", "4.5.0")
      product_22.versions.push( Version.new({ :version => "4.3.0"       }) )
      product_22.versions.push( Version.new({ :version => "4.4.0"       }) )
      product_22.versions.push( Version.new({ :version => "4.5.0"       }) )
      product_22.versions.push( Version.new({ :version => "dev-master"  }) )
      product_22.save

      product_23.versions << Version.new({ :version => "3.3"       })
      product_23.versions << Version.new({ :version => "1.4.0"       })
      product_23.save

      product_24.versions.push( Version.new({ :version => "1.0.0"       }) )
      product_24.versions.push( Version.new({ :version => "0.1.0"       }) )
      product_24.save

      product_25 = ProductFactory.create_for_composer("satooshi/php-coveralls", "1.0.1")
      product_25.versions.push( Version.new({ :version => "1.0.0"        }) )
      product_25.versions.push( Version.new({ :version => "dev-master"   }) )
      product_25.versions.push( Version.new({ :version => "dev-gh-pages" }) )
      product_25.version = '1.0.1'
      product_25.save


      project = parser.parse("https://s3.amazonaws.com/veye_test_env/composer.json")
      expect( project ).not_to be_nil
      expect(project.dependencies.size).to eql(25)


      dep_01 = fetch_by_name(project.dependencies, product_01[:name])
      expect( dep_01.name ).to              eql(product_01[:name])
      expect( dep_01.version_requested ).to eql("2.0.7")
      expect( dep_01.version_current ).to   eql("2.0.7")
      expect( dep_01.stability ).to         eql("stable")
      expect( dep_01.comperator ).to        eql("=")

      dep_02 = fetch_by_name(project.dependencies, product_02[:name])
      expect( dep_02.name ).to              eql(product_02[:name])
      expect( dep_02.version_requested ).to eql("2.0.7")
      expect( dep_02.version_current ).to   eql("2.0.7")
      expect( dep_02.comperator ).to        eql("=")

      dep_03 = fetch_by_name(project.dependencies, product_03[:name])
      expect( dep_03.name ).to              eql(product_03[:name])
      expect( dep_03.version_requested ).to eql("2.0.7")
      expect( dep_03.version_current ).to   eql("2.0.7")
      expect( dep_03.comperator ).to        eql("=")

      dep_04 = fetch_by_name(project.dependencies, product_04[:name])
      expect( dep_04.name ).to              eql(product_04[:name])
      expect( dep_04.version_requested ).to eql("2.0.7")
      expect( dep_04.version_current ).to   eql("2.0.7")
      expect( dep_04.comperator ).to        eql("!=")

      dep_05 = fetch_by_name(project.dependencies, product_05[:name])
      expect( dep_05.name ).to              eql(product_05[:name])
      expect( dep_05.version_requested ).to eql("2.0.7")
      expect( dep_05.version_current ).to   eql("2.0.7")
      expect( dep_05.comperator ).to        eql(">=")

      dep_06 = fetch_by_name(project.dependencies, product_06[:name])
      expect( dep_06.name ).to              eql(product_06[:name])
      expect( dep_06.version_requested ).to eql("2.0.7")
      expect( dep_06.version_current ).to   eql("2.0.8")
      expect( dep_06.comperator ).to        eql("<=")

      dep_07 = fetch_by_name(project.dependencies, product_07[:name])
      expect( dep_07.name ).to              eql(product_07[:name])
      expect( dep_07.version_requested ).to eql("2.0.7")
      expect( dep_07.version_current ).to   eql("2.0.8")
      expect( dep_07.comperator ).to        eql("<")

      dep_08 = fetch_by_name(project.dependencies, product_08[:name])
      expect( dep_08.name ).to              eql(product_08[:name])
      expect( dep_08.version_requested ).to eql("2.0.7")
      expect( dep_08.version_current ).to   eql("2.0.7")
      expect( dep_08.comperator ).to        eql(">")

      dep_09 = fetch_by_name(project.dependencies, product_09[:name])
      expect( dep_09.name ).to              eql(product_09[:name])
      expect( dep_09.version_requested ).to eql("1.9.9")
      expect( dep_09.version_current ).to   eql("2.0.0")
      expect( dep_09.version_label ).to     eql(">=1.9.1,<2.0.0")
      expect( dep_09.comperator ).to        eql("=")

      dep_10 = fetch_by_name(project.dependencies, product_10[:name])
      expect( dep_10.name ).to              eql(product_10[:name])
      expect( dep_10.version_requested ).to eql("2.3")
      expect( dep_10.version_current ).to   eql("2.4")
      expect( dep_10.comperator ).to        eql("=")

      dep_11 = fetch_by_name(project.dependencies, product_11[:name])
      expect( dep_11.name ).to              eql(product_11[:name])
      expect( dep_11.version_requested ).to eql("2.0.7")
      expect( dep_11.version_current ).to   eql("2.0.10")
      expect( dep_11.comperator ).to        eql("=")
      expect( dep_11.stability ).to         eql("stable")

      dep_12 = fetch_by_name(project.dependencies, product_12[:name])
      expect( dep_12.name ).to              eql(product_12[:name])
      expect( dep_12.version_requested ).to eql("2.2.x-dev")
      expect( dep_12.version_current ).to   eql("2.2.x-dev")
      expect( dep_12.comperator ).to        eql("=")
      expect( dep_12.outdated ).to          be_falsey
      expect( dep_12.stability ).to         eql("dev")

      dep_13 = fetch_by_name(project.dependencies, product_13[:name])
      expect( dep_13.name ).to              eql(product_13[:name])
      expect( dep_13.version_label ).to     eql("2.2.*@dev")
      expect( dep_13.version_requested ).to eql("2.2.x-dev")
      expect( dep_13.version_current ).to   eql("2.2.x-dev")
      expect( dep_13.outdated ).to          be_falsey
      expect( dep_13.comperator ).to        eql("=")

      dep_14 = fetch_by_name(project.dependencies, product_14[:name])
      expect( dep_14.name ).to              eql(product_14[:name])
      expect( dep_14.version_label ).to     eql("2.2.*@stable")
      expect( dep_14.version_requested ).to eql("2.2.1")
      expect( dep_14.version_current ).to   eql("2.2.1")
      expect( dep_14.outdated ).to          be_falsey
      expect( dep_14.comperator ).to        eql("=")
      expect( dep_14.stability ).to         eql("stable")

      dep_16 = fetch_by_name(project.dependencies, product_16[:name])
      expect( dep_16.name ).to              eql(product_16[:name])
      expect( dep_16.version_label ).to     eql("@dev")
      expect( dep_16.version_requested ).to eql("2.2.1")
      expect( dep_16.version_current ).to   eql("2.2.1")
      expect( dep_16.comperator ).to        eql("=")

      dep_17 = fetch_by_name(project.dependencies, product_17[:name])
      expect( dep_17.name ).to              eql(product_17[:name])
      expect( dep_17.version_label ).to     eql("~2.2")
      expect( dep_17.version_requested ).to eql("2.3.1")
      expect( dep_17.version_current ).to   eql("3.0.0")
      expect( dep_17.comperator ).to        eql("~")

      dep_18 = fetch_by_name(project.dependencies, product_18[:name])
      expect( dep_18.name ).to              eql(product_18[:name])
      expect( dep_18.version_label ).to     eql(">=2.1,<2.4-dev")
      expect( dep_18.version_requested ).to eql("2.3.x-dev")
      expect( dep_18.version_current ).to   eql("2.3.x-dev")
      expect( dep_18.comperator ).to        eql("=")

      dep_19 = fetch_by_name(project.dependencies, product_19[:name])
      expect( dep_19.name ).to              eql(product_19[:name])
      expect( dep_19.version_label ).to     eql(">=2.1,<2.4-dev")
      expect( dep_19.version_requested ).to eql("2.3-dev")
      expect( dep_19.version_current ).to   eql("2.4-dev")
      expect( dep_19.comperator ).to        eql("=")

      dep_20 = fetch_by_name(project.dependencies, product_20[:name])
      expect( dep_20.name ).to              eql(product_20[:name])
      expect( dep_20.version_label ).to     eql('~3')
      expect( dep_20.version_requested ).to eql('3.7.29')
      expect( dep_20.version_current ).to   eql('3.7.29')
      expect( dep_20.comperator ).to        eql('~')

      dep_21 = fetch_by_name(project.dependencies, product_21[:name])
      expect( dep_21.name ).to              eql(product_21[:name])
      expect( dep_21.version_label ).to     eql('~2.0 | ~1.10')
      expect( dep_21.version_requested ).to eql('2.1.0')
      expect( dep_21.version_current ).to   eql('2.1.0')
      expect( dep_21.comperator ).to        eql('=')

      dep_22 = fetch_by_name(project.dependencies, product_22[:name])
      expect( dep_22.name ).to              eql(product_22[:name])
      expect( dep_22.version_label ).to     eql('^4.3.0')
      expect( dep_22.version_requested ).to eql('4.5.0')
      expect( dep_22.version_current ).to   eql('4.5.0')
      expect( dep_22.comperator ).to        eql('^')


      dep_23 = fetch_by_name(project.dependencies, product_23[:name])
      expect( dep_23.name ).to              eql(product_23[:name])
      expect( dep_23.version_label ).to     eql('3.3')
      expect( dep_23.version_requested ).to eql('3.3')
      expect( dep_23.version_current ).to   eql('3.3')
      expect( dep_23.comperator ).to        eql('=')
      expect( dep_23.language ).to          eql(Product::A_LANGUAGE_JAVASCRIPT)

      dep_24 = fetch_by_name(project.dependencies, product_24[:name])
      expect( dep_24.name ).to              eql(product_24[:name])
      expect( dep_24.version_label ).to     eql('1.0.0')
      expect( dep_24.version_requested ).to eql('1.0.0')
      expect( dep_24.version_current ).to   eql('1.0.0')
      expect( dep_24.comperator ).to        eql('=')
      expect( dep_24.language ).to          eql(Product::A_LANGUAGE_NODEJS)

      dep_25 = fetch_by_name(project.dependencies, "satooshi/php-coveralls")
      expect( dep_25.name ).to              eql('satooshi/php-coveralls')
      expect( dep_25.version_label ).to     eql('dev-master|^1.0')
      expect( dep_25.version_requested ).to eql('1.0.1')
      expect( dep_25.version_current ).to   eql('1.0.1')
      expect( dep_25.comperator ).to        eql('=')
      expect( dep_25.language ).to          eql(Product::A_LANGUAGE_PHP)
    end

  end

  describe "dependency_in_repositories?" do

    it "returns false because of nil parameters" do
      parser = ComposerParser.new
      expect( parser.dependency_in_repositories?(nil, nil) ).to be_falsey
    end

  end

end
