module PolymorphicTypeRestrictions
  Restriction = Struct.new(:attribute_name, :allowed_type)

  class <<self
    def included(base)
      base.module_eval do
        def write_attribute_with_polymorphic_type_restrictions(attribute_name, value)
          if attribute_name.to_s =~ /_type$/
            clazz =
              begin
                value.constantize
              rescue NameError => e
                raise(
                  ActiveRecord::AssociationTypeNameError,
                  e.message
                )
              end
            if restrictions = self.class.read_inheritable_attribute(:polymorphic_type_restrictions)
              restriction = restrictions.find do |restriction|
                restriction.attribute_name == :"#{attribute_name.to_s.sub(/_type$/, '')}"
              end
              if restriction
                unless clazz.ancestors.include?(restriction.allowed_type)
                  raise(
                    ActiveRecord::AssociationTypeMismatch,
                    "#{attribute_name} only allows objects of type #{restriction.allowed_type}"
                  )
                end
              end
            end
          end
          write_attribute_without_polymorphic_type_restrictions(attribute_name, value)
        end

        alias_method_chain :write_attribute, :polymorphic_type_restrictions
      end

      class <<base
        def belongs_to_with_polymorphic_type_restrictions(attribute_name, options = {})
          if allowed_type = options.delete(:allow)
            if allowed_type.respond_to?(:constantize)
              allowed_type = allowed_type.constantize
            end
            write_inheritable_array(:polymorphic_type_restrictions, [Restriction.new(attribute_name.to_sym, allowed_type)])
          end
          belongs_to_without_polymorphic_type_restrictions(attribute_name, options)
        end

        alias_method_chain :belongs_to, :polymorphic_type_restrictions
      end
    end
  end
end

module ActiveRecord
  AssociationTypeNameError = Class.new(NameError)
end
