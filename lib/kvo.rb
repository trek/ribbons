# // KVO Options
KeyValueObservingOptionNew        = 1 << 0
KeyValueObservingOptionOld        = 1 << 1
KeyValueObservingOptionInitial    = 1 << 2
KeyValueObservingOptionPrior      = 1 << 3

# // KVO Change Dictionary Keys
KeyValueChangeKindKey                 = 'KeyValueChangeKindKey'
KeyValueChangeNewKey                  = 'KeyValueChangeNewKey'
KeyValueChangeOldKey                  = 'KeyValueChangeOldKey'
KeyValueChangeIndexesKey              = 'KeyValueChangeIndexesKey'
KeyValueChangeNotificationIsPriorKey  = 'KeyValueChangeNotificationIsPriorKey'

# // KVO Change Types
KeyValueChangeSetting     = 1
KeyValueChangeInsertion   = 2
KeyValueChangeRemoval     = 3
KeyValueChangeReplacement = 4

# convenience
KVONewAndOld = KeyValueObservingOptionNew|KeyValueObservingOptionOld

DependentKeysMap = Hash.new({})
# for has_n relationships, (e.g. has_n :photos) we'll need
#  Cocoa style methods:
#     - photos
#     - countOfPhotos
#     - objectInPhotosAtIndex:
#     - photosAtIndexes:
#     for ordered relationships
#     - insertObject:inPhotosAtIndex:
#     - removeObject:fromPhotosAtIndex:
#     - replaceObjectInPhotosAtIndex:withObject:
#     for unordered relationships
#     - addPhotoObject: or addPhoto:
#     - removePhotoObject: or removePhoto:
# .photos
# .photos.count
# .photos.values_at
#  has_n :photos is ordered, we'll need
# .photos.insert(indexes,object)
# .photos.remove(indexes)
class TextFieldView
  attr_accessor :text_value
  def mouse_up
    if @observed_object_for_text_value
      @observed_object_for_text_value.set_value_for_key_path(@observed_key_path_for_text_value, self.text_value)
    end
  end
  
  def observe_value_for_key_path_of_object_changes_context(path, object, changes, context)
    new_value = @observed_object_for_text_value.value_for_key_path(path)
    self.set_value_for_key('text_value', new_value)
  end
end

class CollectionAssociationProxy
  def initialize(key, owner, target = [])
    @target = target
    @owner  = owner
    @key    = key.to_s
  end
  
  def ==(other)
    @target == other
  end
  
  def value_for_key(key)
    @target.collect {|object| object.value_for_key(key)}
  end
  
  def objects_at_indexes(indexes)
    @target.values_at(indexes)
  end
  
  def insert_object_at_index(obj,index)
    @owner.will_change_value_at_index_for_key(KeyValueChangeInsertion, index, @key)
    @target.insert(index,obj)
    @owner.did_change_value_at_index_for_key(KeyValueChangeInsertion, index, @key)
  end
  
  def size
    @target.size
  end
end

class Object
  def self.has_n(key)
    define_method(key) do
      instance_variable_get("@#{key}") || instance_variable_set("@#{key}", CollectionAssociationProxy.new(key, self))
    end
    
    define_method("#{key}=") do |val|
      instance_variable_set("@#{key}", CollectionAssociationProxy.new(key, self, val))
    end
  end
  
  # Array access
  def mutable_array_value_for_key(key)
    CollectionAssociationProxy.new(key, self)
  end
  
  def mutable_array_value_for_key_path(path)
    dot_index = path.index('.')
    
    unless dot_index
      return self.mutable_array_value_for_key(path)
    end
    
    first_part = path.slice(0, dot_index)
    last_part = path.slice(dot_index+1,path.size)
    
    self.value_for_key_path(first_part).value_for_key_path(last_part)
  end
  
  # Binding
  def bind_to_object_with_key_path_options(attribute, observable_object, key_path, options)
    self.instance_variable_set("@observed_object_for_" + attribute, observable_object)
    self.instance_variable_set("@observed_key_path_for_" + attribute, key_path)
    observable_object.add_observer_for_key_path_options_context(self, key_path, nil, nil)
  end
  
  # KVC
  def set_value_for_key(key,value)
     self.will_change_value_for_key(key)
     instance_variable_set("@#{key}",value)
     self.did_change_value_for_key(key)
  end
  
  def set_value_for_key_path(key_path, value)
    keys = key_path.split('.')
    owner = self
    terminal_key = keys.pop
    
    keys.each do |key|
      owner = owner.value_for_key(key)
    end
    
    owner.set_value_for_key(terminal_key, value)
  end
  
  def value_for_key(key)
    instance_variable_get("@#{key}")
  end
  
  def value_for_key_path(key_path)
    keys = key_path.split('.')
    value = self
    
    keys.each do |key|
      value = value.value_for_key(key)
    end
    
    return value
  end
  
  def array_for_keypath(key_path)
    self.value_for_key_path(key_path)
  end
  
  # KVO
  attr_accessor :forwarder
  def self.automatically_notifies_observers_for_key(key)
    true
  end
  
  def self.key_paths_for_values_affecting_value_for_key(key)
    method = 'key_paths_for_values_affecting_value_for_' + key
    if self.responds_to(method)
      return self.send(method)
    end
    
    return Set.new
  end
  
  def will_change_value_for_key(key)
    return unless key
    change_options = {KeyValueChangeKindKey => KeyValueChangeSetting}
    self.send_notifications_for_key_change_options_is_before(key, change_options, true)
  end
  
  def will_change_value_at_index_for_key(kvo_change, index, key)
    return unless key
    change_options = {KeyValueChangeKindKey => kvo_change, KeyValueChangeIndexesKey => index}
    self.send_notifications_for_key_change_options_is_before(key, change_options, true)
  end
  
  def changes_for_key
    @changes_for_key ||= Hash.new({})
  end
  
  def observers_for_key
    @observers_for_key ||= Hash.new({})
  end
  
  def value_for_key(key)
    self.send(key.intern)
  end
   
  def value_for_key_path(path)
    keys = path.split('.')
    value = self
    
    keys.each do |key|
      value = value.value_for_key(key)
    end
        
    return value
  end 
  
  # the default KVO callback when changes are made.
  def observe_value_for_key_path_of_object_changes_context(path, obj, changes, context)
    
  end
  
  def send_notifications_for_key_change_options_is_before(key, change_options, is_before)
    changes = self.changes_for_key[key]
    
    if is_before
      changes = change_options
      indexes = changes[KeyValueChangeIndexesKey]
      
      if indexes
        type = changes[KeyValueChangeKindKey]
        # for to-many relationships, old value is only sensible for replace and remove
        if (type == KeyValueChangeReplacement || type == KeyValueChangeRemoval)
          # old_values = @target_object[key].values_at(*indexes)
          old_values = @target_object.mutable_array_value_for_key_path(key).objects_at_indexes(indexes)
          changes[KeyValueChangeOldKey] = old_values
        end
      else
        old_value = self.value_for_key(key)
        changes[KeyValueChangeOldKey] = old_value
      end
      
      changes[KeyValueChangeNotificationIsPriorKey] = 1
      self.changes_for_key[key] = changes
    
    else
      changes.delete(KeyValueChangeNotificationIsPriorKey)
      indexes = changes[KeyValueChangeIndexesKey]
      
      if indexes
        type = changes[KeyValueChangeKindKey]
        # for to-many relationships, oldvalue is only sensible for replace and remove
        if (type == KeyValueChangeReplacement || type == KeyValueChangeInsertion)
          old_values = self.mutable_array_value_for_key_path(key).objects_at_indexes(*indexes)
          changes[KeyValueChangeNewKey] = old_values
        end
      else
        new_value = self.value_for_key(key)
        changes[KeyValueChangeNewKey] = new_value
      end
    end
    
    observers = self.observers_for_key[key].values
        
    observers.each do |observer_info|
      if is_before && (observer_info.options & KeyValueObservingOptionPrior)
        observer_info.observer.observe_value_for_key_path_of_object_changes_context(key, self, changes, observer_info.context)
      elsif !is_before
        observer_info.observer.observe_value_for_key_path_of_object_changes_context(key, self, changes, observer_info.context)
      end
    end
    
    # keys_composed_of_key = DependentKeysMap[self.class][key]
    # 
    # return unless keys_composed_of_key
    # 
    # keys_composed_of_key.each do |k|
    #   self.send_notifications_for_key_change_options_is_before(k, change_options, is_before)
    # end
  end
  
  def did_change_value_for_key(key)
    return unless key
    self.send_notifications_for_key_change_options_is_before(key, nil, false)
  end
  
  def did_change_value_at_index_for_key(kvo_change, index_set, key)
    return unless key
    self.send_notifications_for_key_change_options_is_before(key, nil, false)
  end
  
  def add_observer_for_key_path_options_context(observer, key_path, options, context)
    return unless observer
    forwarder = nil
    
    if key_path.include?('.')
      forwarder = KVOForwardingObserver.new(key_path, self, observer, options, context)
    else
      # pft. Ruby is dynamic bitches.
      # [self _replaceSetterForKey:aPath];
    end
    
    observers = self.observers_for_key[key_path]
    
    unless observers
      observers = {}
      self.observers_for_key[key_path] = observers
    end
    
    observers[observer] = KVOInfo.new(observer, options, context, forwarder)
    
    if options & KeyValueObservingOptionInitial
      new_value = self.value_for_key_path(key_path)
      
      changes = {KeyValueChangeNewKey => new_value}
      observer.observe_value_for_key_path_of_object_changes_context(key_path, self, changes, context)
    end    
  end
  
  def remove_observer_for_keypath(observer, key_path)
    observers = self.observers_for_key[key_path]
    
    if key_path.include?('.')
      forwarder = observers[observer].forwarder
      forwarder.finalize   
    end

    observers.delete(observer)
    
    if observers.empty?
      self.observers_for_key.delete(key_path)
    end

  end
end

class KVOForwardingObserver
  attr_accessor :context, :observer, :object, :first_part, :second_part
  def initialize(path, object, observer, options, context)
    @context  = context
    @observer = observer
    @object =  object

    dot_index = path.index('.')
    
    raise "InvalidArgumentException Created KVOForwardingObserver without compound key path: #{path}" unless dot_index
    
    self.first_part = path.slice(0, dot_index)
    self.second_part = path.slice(dot_index+1,path.size)
    
    # become an observer of the first part of our key (a)
    object.add_observer_for_key_path_options_context(self, self.first_part, KVONewAndOld, nil)
    
    # the current value of a (not the value of a.b)
    @value = object.value_for_key(first_part)

    if @value
      @value.add_observer_for_key_path_options_context(self, second_part, KVONewAndOld, nil)
    end
  
    return self
  end
  
  def observe_value_for_key_path_of_object_changes_context(path, obj, changes, context)
    if obj == @object
      @observer.observe_value_for_key_path_of_object_changes_context(@first_part, @object, changes, context)
      # 'obj.a.b'
      # since 'a' has changed, we should remove ourselves as an observer of the old a, and observe the new one
      if @value
        @value.remove_observer_for_keypath(self, @second_part)
      end
      
      @value = @object.value_for_key(@first_part)
      
      if @value
        @value.add_observer_for_key_path_options_context(self, @second_part, KVONewAndOld, nil)
      end
    else  # 'a' is the same, but 'a.b' has changed -- nothing to do but forward this message along
      @observer.observe_value_for_key_path_of_object_changes_context(@first_part + "." + path, @object, changes, @context)
    end
  end
end

class KVOInfo
  attr_accessor :observer, :options, :context, :forwarder
  def initialize(observer, options, context, forwarder)
    @observer  = observer
    @options   = options
    @context   = context
    @forwarder = forwarder
  end
end

class ObjectController
  def self.name
    @name || ""
  end
end

class ObjectWithName
  attr_accessor :name, :current_model
  has_n :listings
  def initialize(name)
    @name = name
  end
  
  def observe_value_for_key_path_of_object_changes_context(path, object, changes, context)
    if path == 'name'
      self.set_value_for_key(path, changes[KeyValueChangeNewKey])
    end
  end
  
  def add_object_to_listings(obj)
    self.will_change_value_at_index_for_key(KeyValueChangeInsertion, self.listings.size, 'listings')
    self.listings << obj
    self.did_change_value_at_index_for_key(KeyValueChangeInsertion, self.listings.size, 'listings')
  end
end

# require 'test/unit'
# require 'test/unit/testsuite'
# require 'test/unit/ui/console/testrunner'
# 
# class KVOObjectKeyTest < Test::Unit::TestCase
#   def setup
#     @o1 = ObjectWithName.new('01')
#     @o2 = ObjectWithName.new('02')
#     @o2.add_observer_for_key_path_options_context(@o1, 'name', nil, nil)
#   end
#   
#   def test_one_object_is_observer_of_another
#     assert @o2.observers_for_key['name'].include?(@o1)
#   end
#   
#   def test_object_update_notifies_observers_for_key
#     @o2.set_value_for_key('name', 'abcdef')
#     assert_equal(@o1.value_for_key('name'), @o2.value_for_key('name'))
#   end
# end
# 
# class KVOHasManyTest < Test::Unit::TestCase
#   def setup
#     @o1 = ObjectWithName.new("oh one")
#   end
#   
#   def test_object_has_has_n_methods
#     assert @o1.respond_to?(:listings)
#     assert @o1.respond_to?(:'listings=')
#   end
#   
#   def test_correct_return_values_for_has_n_methods
#     assert_equal @o1.listings, []
#     
#     @o1.listings = ['a','b','c']
#     assert_equal @o1.listings, ['a','b','c']
#   end
#   
#   def test_notifications_sent_for_collection_insertion
#     @o2 = ObjectWithName.new("oh dos")
#     
#     def @o2.observe_value_for_key_path_of_object_changes_context(path,obj,changes,context)
#       puts changes.inspect
#     end
#     @o1.listings = [1,2,3]
#     
#     @o1.add_observer_for_key_path_options_context(@o2, 'listings', nil, nil)
#     @o1.listings.insert_object_at_index(ObjectWithName.new("oh three"), 0)
#   end
# end
# 
# class ViewBindingTest < Test::Unit::TestCase
#   def setup
#     @v = TextFieldView.new
#     @v.text_value = 'text value 1'
#     @v2 = TextFieldView.new
#     @v2.text_value = 'text value 2'
#     
#     @controller = ObjectWithName.new('controller')
#     @model      = ObjectWithName.new('model')
#     
#     @controller.set_value_for_key('current_model', @model)
#     
#     @v.bind_to_object_with_key_path_options('text_value', @controller, 'current_model.name', nil)
#     @v2.bind_to_object_with_key_path_options('text_value', @controller, 'current_model.name', nil)
#   end
#   
#   def test_model_observations
#     assert_equal 2, @model.observers_for_key['name'].size
#   end
#   
#   def test_view_initiated_update
#     @v.text_value = 'new value typed in'
#     @v.mouse_up
#     assert_equal(@v.text_value, @model.name)
#     assert_equal(@v2.text_value, @model.name)
#   end
#   
#   def test_model_initiated_update
#     @model.set_value_for_key('name', 'XYZ')
#     assert_equal(@v.text_value, @model.name)
#     assert_equal(@v2.text_value, @model.name)
#     
#   end
# end

# class KVOKVCBindingSuite
#   def self.suite
#     suite = Test::Unit::TestSuite.new
#     suite << ViewBindingTest.suite
#     suite << KVOObjectKeyTest.suite
#     suite << KVOHasManyTest.suite
#     return suite
#   end
# end

# Test::Unit::UI::Console::TestRunner.run(KVOKVCBindingSuite)
