module ActsAsShareable  #:nodoc:
  module Shareable

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_shareable(options={})
        has_many :shares, :as => :shareable, :dependent => :destroy
        include ActsAsShareable::Shareable::InstanceMethods
        extend ActsAsShareable::Shareable::SingletonMethods
      end
    end

    # Add class methods here
    module SingletonMethods
      
      def find_shares_by_user(user, *opts)      
        shareable = self.base_class.name
        
        self.includes(:shares).where(shares: {user_id: user.id, shareable_type: shareable})
      end
        
      def find_by_shared_to(object, *opts)
        shareable = self.base_class.name
        shared_to = object.class.name

        options = { :joins=>"LEFT OUTER JOIN shares s ON s.shareable_id = #{self.table_name}.id",
                    :select=>"#{self.table_name}.*",
                    :conditions => ["s.shareable_type =? and s.shared_to_type=? and s.shared_to_id = ?", shareable, shared_to, object.id],
                    :order => "s.created_at DESC"
                  }
        self.includes(:shares).where(shares: {shareable_type: shareable, shared_to_type: shared_to, shared_to_id: object.id})
      end
        
      def find_by_shared_to_and_user(object, user, *opts)
        shareable = self.base_class.name
        shared_to = object.class.name

        options = { :joins=>"LEFT OUTER JOIN shares s ON s.shareable_id = #{self.table_name}.id",
                    :select=>"#{self.table_name}.*",
                    :conditions => ["s.user_id = ? AND s.shareable_type =? and s.shared_to_type=? and s.shared_to_id = ?", user.id, shareable, shared_to, object.id],
                    :order => "s.created_at DESC"
                  }

        self.where(merge_options(options,opts))
      end
        
      private
      
      def merge_options(options, opts)
        if opts && opts[0].is_a?(Hash) && opts[0].has_key?(:conditions)
          cond = opts[0].delete(:conditions)
          options[:conditions][0] << " " << cond.delete_at(0)
          options[:conditions] + cond
        end
        options.merge!(opts[0]) if opts && opts[0].is_a?(Hash)
        return options
      end
        
      end

    # Add instance methods here
    module InstanceMethods   
        
      def share_to(object, by_user)
        unless shared_to?(object, by_user)
          s = Share.new(:user_id=>by_user.id, :shared_to_type=>object.class.name, :shared_to_id=>object.id)
          self.shares << s
          #object.sharings << s
          self.save!
        end
      end
        
      def remove_share_from(object, by_user)
        shareable = self.class.name
        to = object.class.name
        s = Share.where("shareable_type = ? and shareable_id = ? and shared_to_type = ? and shared_to_id = ? and user_id=?", shareable, id, to, object.id, by_user.id).first
        if s
          s.destroy
          reload
          #object.reload
        end
      end
        
      def shared_to?(object, by_user)
        shareable = self.class.name
        to = object.class.name
        s = Share.where("shareable_type = ? and shareable_id = ? and shared_to_type = ? and shared_to_id = ? and user_id=?", shareable, id, to, object.id, by_user.id).first
        return !s.nil?
      end

    end
  end
  
end
