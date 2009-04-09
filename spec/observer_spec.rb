require File.dirname(__FILE__) + '/spec_helper'

describe "key value coding" do
  class KVCObject
    attr_accessor :some_attr
  end
  
  before do
    @object = KVCObject.new
  end
  
  it "should should update instance variables with kvc interface" do
    lambda { @object.set_value_for_key('some_attr', 'some value') }.should_not raise_error
    @object.instance_variable_get("@some_attr").should eql('some value')
  end
  
  it "should access instance variables through kvc interface" do
    @object.set_value_for_key('some_attr', 'some new value')
    @object.value_for_key('some_attr').should eql('some new value')
  end
  
  it "should access notifcations through did/will_change_value interface" do
    @object.should_receive(:will_change_value_for_key).with('some_attr')
    @object.should_receive(:did_change_value_for_key).with('some_attr')
    @object.set_value_for_key('some_attr', 'some new value')
  end
  
  it "should notifiy obserers of value change before and after" do
    @object.should_receive(:send_notifications_for_key_change_options_is_before).exactly(2).times
    @object.set_value_for_key('some_attr', 'some new value')
  end
end

describe "key value observation" do
  class ObservedObject
    has_n :observed_things
    attr_accessor :observed_attribute
  end
  
  class ObservingObject
    def observe_value_for_key_path_of_object_changes_context(path, object, changes, context)
      # puts "object: #{object.inspect}\n"
      puts "changes: #{changes.inspect}\n"
    end
    
    # def observe_value_for_key_path_of_object_changes_context(path, object, changes, context)
    #   @observing_object_was_called = true
    # end
  end
  
  before do
    @observer = ObservingObject.new
    @observed = ObservedObject.new
    
    @observed.add_observer_for_key_path_options_context(@observer, 'observed_attribute', nil, nil)
  end
  
  describe "for has-one relationships and attribute values" do
    describe "from the observed object's point of view" do
      it "should have the observing object listsed in its obsevers for the key" do
        @observed.observers_for_key['observed_attribute'].should have(1).items
        @observed.observers_for_key['observed_attribute'].keys.should include(@observer)
      end
      
      it "should not raise errors when observed value is updated" do
        lambda { @observed.set_value_for_key('observed_attribute', 'something else') }.should_not raise_error
      end
    end
    
    describe "from the observing object's point of view" do
      it "should have observe_value_for_key_path_of_object_changes_context called" do
        @observer.should_receive(:observe_value_for_key_path_of_object_changes_context)
        @observed.set_value_for_key('observed_attribute', 'something else')
      end
    end
  end
  
  describe "for has-n relationships" do
    describe "as the observed object" do
      it "should have setters and getters based on relationship name" do
        @observed.should respond_to(:observed_things)
        @observed.should respond_to(:observed_things=)
      end
      
      it "should return a collection proxy as value of the relationship" do
        @observed.observed_things.should be_kind_of(CollectionAssociationProxy)
      end
      
      describe "adding an object to the collection" do        
        it "should access notifcations through did/will_change_value interface" do
          @observed.should_receive(:will_change_value_at_index_for_key).with(KeyValueChangeInsertion, 0, 'observed_things')
          @observed.should_receive(:did_change_value_at_index_for_key).with(KeyValueChangeInsertion, 0, 'observed_things')
          
          @observed.observed_things.insert_object_at_index(Object.new, 0)
        end
        
        it "should notify observers before and after the change" do
          @observed.should_receive(:send_notifications_for_key_change_options_is_before).exactly(2).times
          @observed.observed_things.insert_object_at_index(Object.new, 0)
        end
      end
    end
    
    describe "as the observing object" do
      describe "adding an object to the collection" do
        it "should received a notifiation of the changes" do
          @object_to_insert = Object.new
          @observer.should_receive(:observe_value_for_key_path_of_object_changes_context).
            with('observed_things', @observed, hash_including("KeyValueChangeNewKey"=>[@object_to_insert],"KeyValueChangeIndexesKey"=>0, "KeyValueChangeKindKey"=>2), nil)
          @observed.observed_things.insert_object_at_index(@object_to_insert, 0)
        end
      end
    end
  end
end

describe "binding" do
  class MockTextFieldView
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
  
  class MockModel
    attr_accessor :name
  end
  
  class MockController
    attr_accessor :mock_model, :unimportant_value
  end
  
  before do
    @text_field = MockTextFieldView.new
    @text_field.text_value = 'xyz'
    
    @not_updated_text_field = MockTextFieldView.new
    
    @controller = MockController.new
    @model      = MockModel.new
    
    @controller.set_value_for_key('mock_model', @model)
  end
  
  describe "to a value" do    
    it "should changes from one value object to the other"
  end
  
  describe "to a value at a path" do
    before do
      @text_field.bind_to_object_with_key_path_options('text_value', @controller, 'mock_model.name', nil)
      @not_updated_text_field.bind_to_object_with_key_path_options('text_value', @controller, 'mock_model.name', nil)
    end
    
    it "should propogate model changes to a view" do
      @model.set_value_for_key('name', 'new name')
      @text_field.text_value.should eql('new name')
      @not_updated_text_field.text_value.should eql('new name')
    end
    
    it "should propogate view changes to the model" do
      @text_field.set_value_for_key('text_value', 'another new, new name')
      @text_field.mouse_up
      @model.name.should eql('another new, new name')
      @not_updated_text_field.text_value.should eql('another new, new name')
    end
  end
end