require 'spec_helper'

describe PackageParser do
  let(:parser){ PackageParser.new }
  let(:product1){ create_product('connect-redis', 'connect-redis', '1.3.0') }
  let(:dep1){ parser.init_dependency(nil, 'test-js-pkg') }

  #TODO: add test cases SEMVER comparition
  context "parse_requested_version" do

    it "returns correct version for `^1.2.3`" do
      product1.versions = []
      product1.versions << Version.new(version: '1.2.3')
      product1.versions << Version.new(version: '1.8.0')
      product1.versions << Version.new(version: '2.0.0')
      product1.versions << Version.new(version: '2.0.1')

      parser.parse_requested_version('^1.2.3', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('1.8.0')
      expect(dep1[:version_label]).to eq('^1.2.3')
      expect(dep1[:comperator]).to eq('^')
    end

    it "returns correct version for `^1.2`" do
      product1.versions = []
      product1.versions << Version.new(version: '1.2.3')
      product1.versions << Version.new(version: '1.8.0')
      product1.versions << Version.new(version: '2.0.0')
      product1.versions << Version.new(version: '2.0.1')

      parser.parse_requested_version('^1.2', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('1.8.0')
      expect(dep1[:version_label]).to eq('^1.2')
      expect(dep1[:comperator]).to eq('^')
    end

    it "returns correct version for `^1`" do
      product1.versions = []
      product1.versions << Version.new(version: '1.0.3')
      product1.versions << Version.new(version: '1.8.0')
      product1.versions << Version.new(version: '2.0.0')
      product1.versions << Version.new(version: '2.0.1')

      parser.parse_requested_version('^1', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('1.8.0')
      expect(dep1[:version_label]).to eq('^1')
      expect(dep1[:comperator]).to eq('^')
    end

    it "returns correct version for `^0.2.3`" do
      product1.versions = []
      product1.versions << Version.new(version: '0.2.3')
      product1.versions << Version.new(version: '0.2.9')
      product1.versions << Version.new(version: '0.3.0')
      product1.versions << Version.new(version: '1.0.1')

      parser.parse_requested_version('^0.2.3', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('0.2.9')
      expect(dep1[:version_label]).to eq('^0.2.3')
      expect(dep1[:comperator]).to eq('^')
    end

    it "returns correct version for `^0.2`" do
      product1.versions = []
      product1.versions << Version.new(version: '0.2.3')
      product1.versions << Version.new(version: '0.2.9')
      product1.versions << Version.new(version: '0.3.0')
      product1.versions << Version.new(version: '0.4.1')

      parser.parse_requested_version('^0.2', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('0.2.9')
      expect(dep1[:version_label]).to eq('^0.2')
      expect(dep1[:comperator]).to eq('^')
    end

    it "returns correct version for `^5.0.0`" do
      # should here include lower border but exlude upper border of the range
      product1.versions = []
      product1.versions << Version.new(version: '0.2.3')
      product1.versions << Version.new(version: '4.0.0')
      product1.versions << Version.new(version: '5.0.0')
      product1.versions << Version.new(version: '6.0.0')

      parser.parse_requested_version('^5.0.0', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('5.0.0')
      expect(dep1[:version_label]).to eq('^5.0.0')
      expect(dep1[:comperator]).to eq('^')
    end



    it "parses correctly version labels with git urls" do
      git_version = 'git+https://example.com/foo/bar#115311855adb0789a0466714ed48a1499ffea97e'
      parser.parse_requested_version(git_version, dep1, product1)

      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('GIT')
      expect(dep1[:version_label]).to eq('115311855adb0789a0466714ed48a1499ffea97e')
      expect(dep1[:comperator]).to eq('=')
    end

    it "parses correctly version labels with urls with tarball" do
      tarbal_version = 'https://example.com/example-1.3.0.tgz'
      parser.parse_requested_version(tarbal_version, dep1, product1)

      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('1.3.0')
      expect(dep1[:version_label]).to eq('1.3.0')
      expect(dep1[:comperator]).to eq('=')
    end

    it "parses correctly version from filepath of the tarball" do
      tarball_version = 'file:///opt/storage/example-1.3.0.tgz'
      parser.parse_requested_version(tarball_version, dep1, product1)

      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('1.3.0')
      expect(dep1[:version_label]).to eq('1.3.0')
      expect(dep1[:comperator]).to eq('=')
    end

    it "returns correct tagged stable version" do
      product1.versions = []
      product1.versions << Version.new(version: '0.9.0', tags: ['next'])
      product1.versions << Version.new(version: '1.0.0', tags: ['next'])
      product1.save

      parser.parse_requested_version('next', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('1.0.0')
      expect(dep1[:version_label]).to eq('next')
      expect(dep1[:comperator]).to eq('=')
    end

    # issue #117 , product: `react-router-redux`
    it "returns correct tagged unstable version" do
      product1.versions = []
      product1.versions << Version.new(version: '5.0.0-alpha.6', tags: ['next'])
      product1.versions << Version.new(version: '5.0.0-alpha.5', tags: ['next'])
      product1.versions << Version.new(version: '5.0.0-alpha.4', tags: ['next'])
      product1.save

      parser.parse_requested_version('next', dep1, product1)
      expect(dep1).not_to be_nil
      expect(dep1[:version_requested]).to eq('5.0.0-alpha.6')
      expect(dep1[:version_label]).to eq('next')
      expect(dep1[:comperator]).to eq('=')
    end
  end


  describe "parse" do

    it "parse from https the file correctly" do
      project = parser.parse('https://s3.amazonaws.com/veye_test_env/package.json')
      expect( project ).to_not be_nil
    end

    it "parse from http the file correctly" do
      product1  = create_product('connect-redis', 'connect-redis', '1.3.0')

      product2  = create_product('redis'        , 'redis'        , '1.3.0')
      product3  = create_product('memcache'     , 'memcache'     , '1.4.0')
      product4  = create_product('mongo'        , 'mongo'        , '1.1.7')
      product5  = create_product('mongoid'      , 'mongoid'      , '1.1.7')
      product6  = create_product('express'      , 'express'      , '2.4.7', ['2.4.0' , '2.4.6', '2.4.7' ] )
      product7  = create_product('fs-ext'       , 'fs-ext'       , '2.4.7', ['0.2.0' , '0.2.7', '2.4.7' ] )
      product8  = create_product('jade'         , 'jade'         , '2.4.7', ['0.2.0' , '0.2.7', '2.4.7' ] )
      product9  = create_product('mailer'       , 'mailer'       , '0.7.0', ['0.6.0' , '0.6.1', '0.6.5', '0.6.9', '0.7.0'])
      product10 = create_product('markdown'     , 'markdown'     , '0.4.0', ['0.2.0' , '0.3.0', '0.4.0' ] )
      product11 = create_product('mu2'          , 'mu2'          , '0.6.0', ['0.5.10', '0.5.0', '0.6.0' ] )
      product12 = create_product('pg'           , 'pg'           , '0.6.6', ['0.5.0' , '0.6.1' ] )
      product13 = create_product('pg_connect'   , 'pg_connect'   , '0.6.9', ['0.5.0' , '0.6.1' ] )

      product14 = create_product('mocha'        , 'mocha'        , '1.16.2', ['1.0.0' , '1.16.0'] )
      product14.versions << Version.new(version: '1.15.0', tags: ['latest'])
      product14.versions << Version.new(version: '1.16.2', tags: ['latest'])
      product14.save

      product15 = create_product('bruno'        , 'bruno'        , '1.12.1', ['1.0.0' , '1.12.0', '1.12.1' ] )
      product16 = create_product('gulp'         , 'gulp'         , '1.12.1', ['1.0.0' , '1.12.0', '1.12.1' ] )

      product17 = create_product('async'        , 'async'        , '0.0.0', ['0.0.0' , '0.8.0', '0.9.0' ] )

      product18 = create_product('gulp-webserver', 'gulp-webserver', '0.9.1', ['0.9.1' , '0.9.0' ] )

      product19 = create_product('eslint'       , 'eslint'       , '1.1.0', ['0.24.0' , '0.24.1', '1.0.0', '1.1.0' ] )
      product20 = create_product('inquirer'     , 'inquirer'     , '0.9.0', ['0.9.0' , '0.8.5', '0.8.4', '0.8.3', '0.8.2', '0.8.0', '0.7.3', '0.7.2' ] )


      parser = PackageParser.new
      project = parser.parse('http://s3.amazonaws.com/veye_test_env/package.json')
      expect( project ).to_not be_nil
      expect( project.dependencies.size ).to eql(21)

      dep_01 = project.dependencies.first
      expect( dep_01.name ).to eql(product1[:name])
      expect( dep_01.version_requested ).to eql('1.3.0')
      expect( dep_01.version_current ).to eql('1.3.0')
      expect( dep_01.comperator ).to eql('=')

      dep_02 = project.dependencies[1]
      expect( dep_02.name ).to eql(product2[:name])
      expect( dep_02.version_requested ).to eql('1.3.0')
      expect( dep_02.version_current ).to eql('1.3.0')
      expect( dep_02.comperator ).to eql('=')

      dep_03 = project.dependencies[2]
      expect( dep_03.name ).to eql(product3[:name])
      expect( dep_03.version_requested ).to eql('1.4.0')
      expect( dep_03.version_current ).to eql('1.4.0')
      expect( dep_03.comperator ).to eql('=')

      dep_04 = project.dependencies[3]
      expect( dep_04.name ).to eql(product4[:name])
      expect( dep_04.version_requested ).to eql('1.1.7')
      expect( dep_04.version_current ).to eql('1.1.7')
      expect( dep_04.comperator ).to eql('=')

      dep_05 = project.dependencies[4]
      expect( dep_05.name ).to eql(product5[:name])
      expect( dep_05.version_requested ).to eql('1.1.7')
      expect( dep_05.version_current ).to eql('1.1.7')
      expect( dep_05.comperator ).to eql('=')

      dep_06 = project.dependencies[5]
      expect( dep_06.name ).to eql(product6[:name])
      expect( dep_06.version_requested ).to eql('2.4.7')
      expect( dep_06.version_current ).to eql('2.4.7')
      expect( dep_06.comperator ).to eql('=')

      dep_07 = project.dependencies[6]
      expect( dep_07.name ).to eql(product7[:name])
      expect( dep_07.version_requested ).to eql('0.2.7')
      expect( dep_07.version_current ).to eql('2.4.7')
      expect( dep_07.comperator ).to eql('=')

      dep_08 = project.dependencies[7]
      expect( dep_08.name ).to eql(product8[:name])
      expect( dep_08.version_requested ).to eql('0.2.7')
      expect( dep_08.version_current ).to eql('2.4.7')
      expect( dep_08.comperator ).to eql('~')

      dep_09 = project.dependencies[8]
      expect( dep_09.name ).to eql(product9[:name])
      expect( dep_09.version_requested ).to eql('0.6.9')
      expect( dep_09.version_current ).to eql('0.7.0')
      expect( dep_09.comperator ).to eql('=')

      dep_10 = project.dependencies[9]
      expect( dep_10.name ).to eql(product10[:name])
      expect( dep_10.version_requested ).to eql('0.2.0')
      expect( dep_10.version_current ).to eql('0.4.0')
      expect( dep_10.comperator ).to eql('<')

      dep_11 = project.dependencies[10]
      expect( dep_11.name ).to eql(product11[:name])
      expect( dep_11.version_requested ).to eql('0.6.0')
      expect( dep_11.version_current ).to eql('0.6.0')
      expect( dep_11.comperator ).to eql('>')

      dep_12 = project.dependencies[11]
      expect( dep_12.name ).to eql(product12[:name])
      expect( dep_12.version_requested ).to eql('0.6.6')
      expect( dep_12.version_current ).to eql('0.6.6')
      expect( dep_12.comperator ).to eql('>=')

      dep_13 = project.dependencies[12]
      expect( dep_13.name ).to eql(product13[:name])
      expect( dep_13.version_requested ).to eql('0.6.9')
      expect( dep_13.version_current ).to eql('0.6.9')
      expect( dep_13.comperator ).to eql('<=')

      dep_14 = project.dependencies[13]
      expect( dep_14.name ).to eql(product14[:name])
      expect( dep_14.version_requested ).to eql('1.16.2')
      expect( dep_14.version_current ).to eql('1.16.2')
      expect( dep_14.comperator ).to eql('=')
      expect( dep_14.version_label ).to eql('latest')
      expect( dep_14.outdated?() ).to be_falsey

      dep_15 = project.dependencies[14]
      expect( dep_15.name ).to eql(product15[:name])
      expect( dep_15.version_requested ).to eql('1.12.1')
      expect( dep_15.version_current ).to eql('1.12.1')
      expect( dep_15.comperator ).to eql('^')
      expect( dep_15.version_label ).to eql('^1.12')
      expect( dep_15.outdated?() ).to be_falsey

      dep_15 = project.dependencies[15]
      expect( dep_15.name ).to eql(product16[:name])
      expect( dep_15.version_requested ).to eql('1.12.1')
      expect( dep_15.version_current ).to eql('1.12.1')
      expect( dep_15.comperator ).to eql('!=')
      expect( dep_15.version_label ).to eql('1.0')
      expect( dep_15.outdated?() ).to be_falsey

      dep_16 = project.dependencies[16]
      expect( dep_16.name ).to eql(product17[:name])
      expect( dep_16.version_requested ).to eql('0.9.0')
      expect( dep_16.version_current ).to eql('0.9.0')
      expect( dep_16.comperator ).to eql('=')
      expect( dep_16.version_label ).to eql('0.x')
      expect( dep_16.outdated?() ).to be_falsey

      dep_17 = project.dependencies[17]
      expect( dep_17.name ).to eql(product18[:name])
      expect( dep_17.version_label ).to eql('^0.9.*')
      expect( dep_17.version_requested ).to eql('0.9.1')
      expect( dep_17.version_current ).to eql('0.9.1')
      expect( dep_17.comperator ).to eql('^')
      expect( dep_17.outdated?() ).to be_falsey

      dep_18 = project.dependencies[18]
      expect( dep_18.name ).to eql(product19[:name])
      expect( dep_18.version_label ).to eql('^0.24.0')
      expect( dep_18.version_requested ).to eql('0.24.1')
      expect( dep_18.version_current ).to eql('1.1.0')
      expect( dep_18.comperator ).to eql('^')
      expect( dep_18.outdated?() ).to be_truthy

      dep_19 = project.dependencies[19]
      expect( dep_19.name ).to eql(product20[:name])
      expect( dep_19.version_label ).to eql('^0.8.0')
      expect( dep_19.version_requested ).to eql('0.8.5')
      expect( dep_19.version_current ).to eql('0.9.0')
      expect( dep_19.comperator ).to eql('^')
      expect( dep_19.outdated?() ).to be_truthy
    end

  end

  describe 'pre_process' do

    it 'returns the changed version' do
      expect( described_class.new.pre_process("4") ).to eq("4.*")
    end
    it 'returns the changed version' do
      expect( described_class.new.pre_process("4.2") ).to eq("4.2.*")
    end
    it 'returns the unchanged version' do
      expect( described_class.new.pre_process("4.2.2") ).to eq("4.2.2")
    end

  end

  def create_product(name, prod_key, version, versions = nil )
    product = Product.new({ :language => Product::A_LANGUAGE_NODEJS, :prod_type => Project::A_TYPE_NPM })
    product.name = name
    product.prod_key = prod_key
    product.version = version
    product.add_version( version )
    product.save

    return product if !versions

    versions.each do |ver|
      product.add_version( ver )
    end
    product.save

    product
  end

end
