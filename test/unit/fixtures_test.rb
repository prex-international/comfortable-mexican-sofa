# encoding: utf-8

require File.expand_path('../test_helper', File.dirname(__FILE__))

class FixturesTest < ActiveSupport::TestCase
  
  def test_import_layouts_creating
    Cms::Layout.delete_all
    
    assert_difference 'Cms::Layout.count', 2 do
      ComfortableMexicanSofa::Fixture::Layout::Importer.new('sample-site', 'default-site').import!
      
      assert layout = Cms::Layout.where(:identifier => 'default').first
      assert_equal 'Default Fixture Layout', layout.label
      assert_equal "<html>\n  <body>\n    {{ cms:page:content }}\n  </body>\n</html>", layout.content
      assert_equal 'body{color: red}', layout.css
      assert_equal '// default js', layout.js
      
      assert nested_layout = Cms::Layout.where(:identifier => 'nested').first
      assert_equal layout, nested_layout.parent
      assert_equal 'Default Fixture Nested Layout', nested_layout.label
      assert_equal "<div class='left'> {{ cms:page:left }} </div>\n<div class='right'> {{ cms:page:right }} </div>", nested_layout.content
      assert_equal 'div{float:left}', nested_layout.css
      assert_equal '// nested js', nested_layout.js
    end
  end
  
  def test_import_layouts_updating_and_deleting
    layout        = cms_layouts(:default)
    nested_layout = cms_layouts(:nested)
    child_layout  = cms_layouts(:child)
    layout.update_column(:updated_at, 10.years.ago)
    nested_layout.update_column(:updated_at, 10.years.ago)
    child_layout.update_column(:updated_at, 10.years.ago)
    
    assert_difference 'Cms::Layout.count', -1 do
      ComfortableMexicanSofa::Fixture::Layout::Importer.new('sample-site', 'default-site').import!
      
      layout.reload
      assert_equal 'Default Fixture Layout', layout.label
      assert_equal "<html>\n  <body>\n    {{ cms:page:content }}\n  </body>\n</html>", layout.content
      assert_equal 'body{color: red}', layout.css
      assert_equal '// default js', layout.js
      assert_equal 0, layout.position
      
      nested_layout.reload
      assert_equal layout, nested_layout.parent
      assert_equal 'Default Fixture Nested Layout', nested_layout.label
      assert_equal "<div class='left'> {{ cms:page:left }} </div>\n<div class='right'> {{ cms:page:right }} </div>", nested_layout.content
      assert_equal 'div{float:left}', nested_layout.css
      assert_equal '// nested js', nested_layout.js
      assert_equal 42, nested_layout.position
      
      assert_nil Cms::Layout.where(:identifier => 'child').first
    end
  end
  
  def test_import_layouts_ignoring
    layout = cms_layouts(:default)
    layout_path       = File.join(ComfortableMexicanSofa.config.fixtures_path, 'sample-site', 'layouts', 'default')
    attr_file_path    = File.join(layout_path, 'attributes.yml')
    content_file_path = File.join(layout_path, 'content.html')
    css_file_path     = File.join(layout_path, 'stylesheet.css')
    js_file_path      = File.join(layout_path, 'javascript.js')
    
    assert layout.updated_at >= File.mtime(attr_file_path)
    assert layout.updated_at >= File.mtime(content_file_path)
    assert layout.updated_at >= File.mtime(css_file_path)
    assert layout.updated_at >= File.mtime(js_file_path)
    
    ComfortableMexicanSofa::Fixture::Layout::Importer.new('sample-site', 'default-site').import!
    layout.reload
    assert_equal 'default', layout.identifier
    assert_equal 'Default Layout', layout.label
    assert_equal "{{cms:field:default_field_text:text}}\nlayout_content_a\n{{cms:page:default_page_text:text}}\nlayout_content_b\n{{cms:snippet:default}}\nlayout_content_c", layout.content
    assert_equal 'default_css', layout.css
    assert_equal 'default_js', layout.js
  end
  
  def test_import_layouts_forcing
    layout = cms_layouts(:default)
    ComfortableMexicanSofa::Fixture::Layout::Importer.new('sample-site', 'default-site').import!
    layout.reload
    assert_equal 'Default Layout', layout.label
    
    ComfortableMexicanSofa::Fixture::Layout::Importer.new('sample-site', 'default-site', :forced).import!
    layout.reload
    assert_equal 'Default Fixture Layout', layout.label
  end
  
  def test_import_pages_creating
    Cms::Page.delete_all
    
    layout = cms_layouts(:default)
    layout.update_column(:content, '<html>{{cms:page:content}}</html>')
    
    nested = cms_layouts(:nested)
    nested.update_column(:content, '<html>{{cms:page:left}}<br/>{{cms:page:right}}</html>')
    
    assert_difference 'Cms::Page.count', 2 do
      ComfortableMexicanSofa::Fixture::Page::Importer.new('sample-site', 'default-site').import!
      
      assert page = Cms::Page.where(:full_path => '/').first
      assert_equal layout, page.layout
      assert_equal 'index', page.slug
      assert_equal "<html>Home Page Fixture Contént\ndefault_snippet_content</html>", page.content
      assert_equal 0, page.position
      assert page.is_published?
      
      assert child_page = Cms::Page.where(:full_path => '/child').first
      assert_equal page, child_page.parent
      assert_equal nested, child_page.layout
      assert_equal 'child', child_page.slug
      assert_equal '<html>Child Page Left Fixture Content<br/>Child Page Right Fixture Content</html>', child_page.content
      assert_equal 42, child_page.position
    end
  end
  
  def test_import_pages_updating_and_deleting
    page = cms_pages(:default)
    page.update_column(:updated_at, 10.years.ago)
    assert_equal 'Default Page', page.label
    
    child = cms_pages(:child)
    child.update_column(:slug, 'old')
    
    assert_no_difference 'Cms::Page.count' do
      ComfortableMexicanSofa::Fixture::Page::Importer.new('sample-site', 'default-site').import!
      
      page.reload
      assert_equal 'Home Fixture Page', page.label
      
      assert_nil Cms::Page.where(:slug => 'old').first
    end
  end
  
  def test_import_pages_ignoring
    Cms::Page.destroy_all
    
    page = cms_sites(:default).pages.create!(
      :label  => 'Test',
      :layout => cms_layouts(:default),
      :blocks_attributes => [ { :identifier => 'content', :content => 'test content' } ]
    )
    
    page_path         = File.join(ComfortableMexicanSofa.config.fixtures_path, 'sample-site', 'pages', 'index')
    attr_file_path    = File.join(page_path, 'attributes.yml')
    content_file_path = File.join(page_path, 'content.html')
    
    assert page.updated_at >= File.mtime(attr_file_path)
    assert page.updated_at >= File.mtime(content_file_path)
    
    ComfortableMexicanSofa::Fixture::Page::Importer.new('sample-site', 'default-site').import!
    page.reload
    
    assert_equal nil, page.slug
    assert_equal 'Test', page.label
    block = page.blocks.where(:identifier => 'content').first
    assert_equal 'test content', block.content
  end
  
  def test_import_pages_forcing
    page = cms_pages(:default)
    ComfortableMexicanSofa::Fixture::Page::Importer.new('sample-site', 'default-site').import!
    page.reload
    assert_equal 'Default Page', page.label
    
    ComfortableMexicanSofa::Fixture::Page::Importer.new('sample-site', 'default-site', :forced).import!
    page.reload
    assert_equal 'Home Fixture Page', page.label
  end
  
  def test_import_pages_removing_deleted_blocks
    Cms::Page.destroy_all
    
    page = cms_sites(:default).pages.create!(
      :label  => 'Test',
      :layout => cms_layouts(:default),
      :blocks_attributes => [ { :identifier => 'to_delete', :content => 'test content' } ]
    )
    page.update_column(:updated_at, 10.years.ago)
    
    ComfortableMexicanSofa::Fixture::Page::Importer.new('sample-site', 'default-site').import!
    page.reload
    
    block = page.blocks.where(:identifier => 'content').first
    assert_equal "Home Page Fixture Contént\n{{ cms:snippet:default }}", block.content
    
    block = page.blocks.where(:identifier => 'to_delete').first
    assert_equal nil, block.content
  end
  
  def test_import_snippets_creating
    Cms::Snippet.delete_all
    
    assert_difference 'Cms::Snippet.count' do
      ComfortableMexicanSofa::Fixture::Snippet::Importer.new('sample-site', 'default-site').import!
      assert snippet = Cms::Snippet.last
      assert_equal 'default', snippet.identifier
      assert_equal 'Default Fixture Snippet', snippet.label
      assert_equal 'Fixture Content for Default Snippet', snippet.content
    end
  end
  
  def test_import_snippets_updating
    snippet = cms_snippets(:default)
    snippet.update_column(:updated_at, 10.years.ago)
    assert_equal 'default', snippet.identifier
    assert_equal 'Default Snippet', snippet.label
    assert_equal 'default_snippet_content', snippet.content
    
    assert_no_difference 'Cms::Snippet.count' do
      ComfortableMexicanSofa::Fixture::Snippet::Importer.new('sample-site', 'default-site').import!
      snippet.reload
      assert_equal 'default', snippet.identifier
      assert_equal 'Default Fixture Snippet', snippet.label
      assert_equal 'Fixture Content for Default Snippet', snippet.content
    end
  end
  
  def test_import_snippets_deleting
    snippet = cms_snippets(:default)
    snippet.update_column(:identifier, 'old')
    
    assert_no_difference 'Cms::Snippet.count' do
      ComfortableMexicanSofa::Fixture::Snippet::Importer.new('sample-site', 'default-site').import!
      assert snippet = Cms::Snippet.last
      assert_equal 'default', snippet.identifier
      assert_equal 'Default Fixture Snippet', snippet.label
      assert_equal 'Fixture Content for Default Snippet', snippet.content
      
      assert_nil Cms::Snippet.find_by_identifier('old')
    end
  end
  
  def test_import_snippets_ignoring
    snippet = cms_snippets(:default)
    snippet_path      = File.join(ComfortableMexicanSofa.config.fixtures_path, 'sample-site', 'snippets', 'default')
    attr_file_path    = File.join(snippet_path, 'attributes.yml')
    content_file_path = File.join(snippet_path, 'content.html')
    
    assert snippet.updated_at >= File.mtime(attr_file_path)
    assert snippet.updated_at >= File.mtime(content_file_path)
    
    ComfortableMexicanSofa::Fixture::Snippet::Importer.new('sample-site', 'default-site').import!
    snippet.reload
    assert_equal 'default', snippet.identifier
    assert_equal 'Default Snippet', snippet.label
    assert_equal 'default_snippet_content', snippet.content
  end
  
  def test_import_snippets_forcing
    snippet = cms_snippets(:default)
    ComfortableMexicanSofa::Fixture::Snippet::Importer.new('sample-site', 'default-site').import!
    snippet.reload
    assert_equal 'Default Snippet', snippet.label
    
    ComfortableMexicanSofa::Fixture::Snippet::Importer.new('sample-site', 'default-site', :forced).import!
    snippet.reload
    assert_equal 'Default Fixture Snippet', snippet.label
  end
  
  def test_import_all
    Cms::Page.destroy_all
    Cms::Layout.destroy_all
    Cms::Snippet.destroy_all
    
    assert_difference 'Cms::Layout.count', 2 do
      assert_difference 'Cms::Page.count', 2 do
        assert_difference 'Cms::Snippet.count', 1 do
          ComfortableMexicanSofa::Fixture::Importer.new('sample-site', 'default-site').import!
        end
      end
    end
  end
  
  def test_import_all_with_no_site
    cms_sites(:default).destroy
    
    assert_exception_raised ActiveRecord::RecordNotFound do
      ComfortableMexicanSofa::Fixture::Importer.new('sample-site', 'default-site').import!
    end
  end
  
  def test_export_layouts
    host_path = File.join(ComfortableMexicanSofa.config.fixtures_path, 'test-site')
    layout_1_attr_path    = File.join(host_path, 'layouts/nested/attributes.yml')
    layout_1_content_path = File.join(host_path, 'layouts/nested/content.html')
    layout_1_css_path     = File.join(host_path, 'layouts/nested/stylesheet.css')
    layout_1_js_path      = File.join(host_path, 'layouts/nested/javascript.js')
    layout_2_attr_path    = File.join(host_path, 'layouts/nested/child/attributes.yml')
    layout_2_content_path = File.join(host_path, 'layouts/nested/child/content.html')
    layout_2_css_path     = File.join(host_path, 'layouts/nested/child/stylesheet.css')
    layout_2_js_path      = File.join(host_path, 'layouts/nested/child/javascript.js')
    
    ComfortableMexicanSofa::Fixture::Layout::Exporter.new('default-site', 'test-site').export!
    
    assert File.exists?(layout_1_attr_path)
    assert File.exists?(layout_1_content_path)
    assert File.exists?(layout_1_css_path)
    assert File.exists?(layout_1_js_path)
    
    assert File.exists?(layout_2_attr_path)
    assert File.exists?(layout_2_content_path)
    assert File.exists?(layout_2_css_path)
    assert File.exists?(layout_2_js_path)
    
    assert_equal ({
      'label'       => 'Nested Layout',
      'app_layout'  => nil,
      'position'    => 0
    }), YAML.load_file(layout_1_attr_path)
    assert_equal cms_layouts(:nested).content, IO.read(layout_1_content_path)
    assert_equal cms_layouts(:nested).css, IO.read(layout_1_css_path)
    assert_equal cms_layouts(:nested).js, IO.read(layout_1_js_path)
    
    assert_equal ({
      'label'       => 'Child Layout',
      'app_layout'  => nil,
      'position'    => 0
    }), YAML.load_file(layout_2_attr_path)
    assert_equal cms_layouts(:child).content, IO.read(layout_2_content_path)
    assert_equal cms_layouts(:child).css, IO.read(layout_2_css_path)
    assert_equal cms_layouts(:child).js, IO.read(layout_2_js_path)
    
    FileUtils.rm_rf(host_path)
  end
  
  def test_export_pages
    host_path = File.join(ComfortableMexicanSofa.config.fixtures_path, 'test-site')
    page_1_attr_path    = File.join(host_path, 'pages/index/attributes.yml')
    page_1_block_a_path = File.join(host_path, 'pages/index/default_field_text.html')
    page_1_block_b_path = File.join(host_path, 'pages/index/default_page_text.html')
    page_2_attr_path    = File.join(host_path, 'pages/index/child-page/attributes.yml')
    
    ComfortableMexicanSofa::Fixture::Page::Exporter.new('default-site', 'test-site').export!
    
    assert_equal ({
      'label'         => 'Default Page',
      'layout'        => 'default',
      'parent'        => nil,
      'target_page'   => nil,
      'is_published'  => true,
      'position'      => 0
    }), YAML.load_file(page_1_attr_path)
    assert_equal cms_blocks(:default_field_text).content, IO.read(page_1_block_a_path)
    assert_equal cms_blocks(:default_page_text).content, IO.read(page_1_block_b_path)
    
    assert_equal ({
      'label'         => 'Child Page',
      'layout'        => 'default',
      'parent'        => 'index',
      'target_page'   => nil,
      'is_published'  => true,
      'position'      => 0
    }), YAML.load_file(page_2_attr_path)
    
    FileUtils.rm_rf(host_path)
  end
  
  def test_export_snippets
    host_path = File.join(ComfortableMexicanSofa.config.fixtures_path, 'test-site')
    attr_path     = File.join(host_path, 'snippets/default/attributes.yml')
    content_path  = File.join(host_path, 'snippets/default/content.html')
    
    ComfortableMexicanSofa::Fixture::Snippet::Exporter.new('default-site', 'test-site').export!
    
    assert File.exists?(attr_path)
    assert File.exists?(content_path)
    assert_equal ({'label' => 'Default Snippet'}), YAML.load_file(attr_path)
    assert_equal cms_snippets(:default).content, IO.read(content_path)
    
    FileUtils.rm_rf(host_path)
  end
  
  def test_export_all
    host_path = File.join(ComfortableMexicanSofa.config.fixtures_path, 'test-site')
    ComfortableMexicanSofa::Fixture::Exporter.new('default-site', 'test-site').export!
    FileUtils.rm_rf(host_path)
  end
  
end