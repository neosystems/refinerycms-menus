module Refinery
  module Menus
    class MenuLink < Refinery::Core::BaseModel
      translates :label
      self.table_name = "refinery_menus_links"
      
      attr_accessible :parent_id, :refinery_page_id, :refinery_menu_id, :resource, :resource_id, :resource_type,
                      :title_attribute, :custom_url, :label, :menu, :id_attribute, :class_attribute, :image_id

      belongs_to :menu, :class_name => '::Refinery::Menus::Menu', :foreign_key => :refinery_menu_id      
      belongs_to :resource, :polymorphic => true
      belongs_to :image, :class_name => '::Refinery::Image'

      # Docs for acts_as_nested_set https://github.com/collectiveidea/awesome_nested_set
      # rather than :delete_all we want :destroy
      acts_as_nested_set :dependent => :destroy

      validates :menu, :presence => true
      validates :label, :presence => true

      before_validation :set_label

      def self.find_all_of_type(type)
        # find all resources of the given type, determined by the configuration
        # TODO - we may want to allow configuration of conditions (DONE), ordering, etc
        if scope = self.resource_config(type)[:scope]
          scope.is_a?(Symbol) ? resource_klass(type).send(scope) : resource_klass(type).instance_eval(&scope)
        else
          resource_klass(type).all
        end
      end

      def self.resource_klass(type)
        resource_config(type)[:klass].constantize
      end

      def self.resource_config(type)
        Refinery::Menus.menu_resources[type.to_sym]
      end

      def set_label
        if label.blank?
          if custom_link?
            begin
              self.label = custom_url.match(/(\w+)\.\w+$/).captures.join.titleize
            rescue
              self.label = custom_url
            end
          else
            self.label = resource.send(resource_config[:title_attr])
          end
        end
      end

      def resource_klass
        Refinery::Menus::MenuLink.resource_klass(resource_type)
      end

      def resource_config
        Refinery::Menus::MenuLink.resource_config(resource_type)
      end

      def resource_type
        super || "Custom link"
      end

      def type_name
        resource_type.titleize
      end

      def custom_link?
        resource_id.nil? || resource_type.nil?
      end

      def resource_link?
        resource_id.present? && resource_type.present?
      end

      def resource
        return nil if custom_link?
        resource_klass.find(resource_id)
      end

      def resource_title
        resource.send(resource_config[:title_attr])
      end

      def title
        title_attribute.present? ? title_attribute : label
      end

      def resource_url
        resource.present? ? resource.url : '/'
      end

      def resource=(record)
        klass = record.class.base_class.name
        key = klass.underscore.tr!("-", "_")
        if Refinery::Menus.menu_resources.has_key?(key)
          super
          resource_type = key
        elsif type = Refinery::Menus.menu_resources.detect{|k,v| v.has_key?(:klass) && v[:klass] = klass}.first
          resource_type = type
        end
      end

      def url
        if custom_link?
          custom_url
        else
          resource_url
        end
      end

      def as_json(options={})
        json = super(options)
        if resource_link?
          json = {
            resource: {
              title: resource_title
            }
          }.merge(json)
        end
        json
      end

      def to_refinery_menu_item
        {
          :id => id,
          :lft => lft,
          :menu_match => menu_match,
          :parent_id => parent_id,
          :rgt => rgt,
          :title => label,
          :type => self.class.name,
          :url => url,
          :html => {
            :id => id_attribute,
            :class => class_attribute,
            :title => title
          }
        }
      end

    end
  end
end
