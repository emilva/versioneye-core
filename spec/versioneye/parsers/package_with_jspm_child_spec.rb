require 'spec_helper'

describe PackageParser do
  let(:parser){ PackageParser.new }
  let(:test_content){ File.read('spec/fixtures/files/npm/package_jspm_child.json') }

  let(:backbone_es6){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'backbone-es6',
      name: 'backbone-es6',
      version: '1.0.0'
    )
  }

  let(:underscore){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'underscore',
      name: 'underscore',
      version: '1.0.0'
    )
  }

  let(:babel){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'babel',
      name: 'babel',
      version: '5.0.0'
    )
  }

  let(:gulp){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'gulp',
      name: 'gulp',
      version: '3.0.0'
    )
  }

  let(:jspm){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'jspm',
      name: 'jspm',
      version: '0.16.0'
    )
  }

  # it should parse correclty dependencies of NPM packages
  # and then create child_project for JSPM dependencies
  context "parse_content" do
    before do
      backbone_es6.save;

      underscore.versions << Version.new(version: '1.0.0')
      underscore.save

      babel.versions << Version.new(version: '4.9.9')
      babel.versions << Version.new(version: '5.0.0')
      babel.versions << Version.new(version: '6.0.0')
      babel.save

      gulp.versions << Version.new(version: '3.0.0')
      gulp.save

      jspm.versions << Version.new(version: '0.16.0')
      jspm.save
    end

    after do
      Project.delete_all
      Projectdependency.delete_all
    end

    it "parses test file correctly" do
      proj = parser.parse_content test_content
      proj.save
      proj = Project.find proj.ids
      expect( proj ).not_to be_nil
      expect(proj.dependencies.count).to eq(5)
      expect(proj.dep_number).to eq(5) # 2 NPM + 3 JSPM deps

      # check did we get all the dependencies for parent project right
      dep1 = proj.dependencies[0]
      expect(dep1[:name]).to eq(gulp[:name])
      expect(dep1[:prod_key]).to eq(gulp[:prod_key])
      expect(dep1[:language]).to eq(gulp[:language])
      expect(dep1[:scope]).to eq(Dependency::A_SCOPE_DEVELOPMENT)
      expect(dep1[:version_requested]).to eq('3.0.0')
      expect(dep1[:version_label]).to eq('^3.0.0')
      expect(dep1[:comperator]).to eq('^')
      expect(dep1[:outdated]).to be_falsey

      dep2 = proj.dependencies[1]
      expect(dep2[:name]).to eq(jspm[:name])
      expect(dep2[:prod_key]).to eq(jspm[:prod_key])
      expect(dep2[:language]).to eq(jspm[:language])
      expect(dep2[:scope]).to eq(Dependency::A_SCOPE_DEVELOPMENT)
      expect(dep2[:version_requested]).to eq('0.16.0')
      expect(dep2[:version_label]).to eq('^0.16.0')
      expect(dep2[:comperator]).to eq('^')
      expect(dep2[:outdated]).to be_falsey

      cdep1 = proj.dependencies[2]
      expect(cdep1[:name]).to eq(backbone_es6[:name])
      expect(cdep1[:prod_key]).to eq(backbone_es6[:prod_key])
      expect(cdep1[:language]).to eq(backbone_es6[:language])
      expect(cdep1[:scope]).to eq("jspm_#{Dependency::A_SCOPE_COMPILE}")
      expect(cdep1[:version_requested]).to eq('github@master')
      expect(cdep1[:version_label]).to eq('github@master')
      expect(cdep1[:comperator]).to eq('=')
      expect(cdep1[:outdated]).to be_falsey

      cdep2 = proj.dependencies[3]
      expect(cdep2[:name]).to eq(underscore[:name])
      expect(cdep2[:prod_key]).to eq(underscore[:prod_key])
      expect(cdep2[:language]).to eq(underscore[:language])
      expect(cdep2[:scope]).to eq("jspm_#{Dependency::A_SCOPE_COMPILE}")
      expect(cdep2[:version_requested]).to eq('1.0.0')
      expect(cdep2[:version_label]).to eq('^1.0.0')
      expect(cdep2[:comperator]).to eq('^')
      expect(cdep2[:outdated]).to be_falsey

      cdep3 = proj.dependencies[4]
      expect(cdep3[:name]).to eq(babel[:name])
      expect(cdep3[:prod_key]).to eq(babel[:prod_key])
      expect(cdep3[:language]).to eq(babel[:language])
      expect(cdep3[:scope]).to eq("jspm_#{Dependency::A_SCOPE_DEVELOPMENT}")
      expect(cdep3[:version_requested]).to eq('5.0.0')
      expect(cdep3[:version_label]).to eq('^5.0.0')
      expect(cdep3[:comperator]).to eq('^')
      expect(cdep3[:outdated]).to be_truthy

    end
  end
end
