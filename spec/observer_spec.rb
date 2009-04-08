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
  
  it "should notifiy obserers of value change before and after" do
    @object.should_receive(:will_change_value_for_key).with('some_attr')
    @object.should_receive(:did_change_value_for_key).with('some_attr')
    # @object.should_receive(:send_notifications_for_key_change_options_is_before).exactly(2).times
    
    @object.set_value_for_key('some_attr', 'some new value')
  end
end

describe "key value observation" do
  class ObservedObject
    attr_accessor :observed_attribute
  end
  
  class ObservingObject
    def observe_value_for_key_path_of_object_changes_context(path, object, changes, context)
      @observing_object_was_called = true
    end
  end
  
  describe "from the observed object's point of view" do
    before do
      @observer = ObservingObject.new
      @observed = ObservedObject.new
    
      @observed.add_observer_for_key_path_options_context(@observer, 'observed_attribute', nil, nil)
    end
  
    it "should have the observing object listsed in its obsevers for the key" do
      @observed.observers_for_key['observed_attribute'].should have(1).items
      @observed.observers_for_key['observed_attribute'].keys.should include(@observer)
    end
    
    it "should not raise errors when observed value is updated" do
      lambda { @observed.set_value_for_key('observed_attribute', 'something else') }.should_not raise_error
    end
  end
  
  describe "from the observing object's point of view" do
    before do
      @observer = ObservingObject.new
      @observed = ObservedObject.new
    
      @observed.add_observer_for_key_path_options_context(@observer, 'observed_attribute', nil, nil)
    end
    
    it "should have observe_value_for_key_path_of_object_changes_context called" do
      @observer.should_receive(:observe_value_for_key_path_of_object_changes_context)
      @observed.set_value_for_key('observed_attribute', 'something else')
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
    attr_accessor :mock_model
  end
  
  before do
    @text_field = MockTextFieldView.new
    @text_field.text_value = 'xyz'
    
    @not_updated_text_field = MockTextFieldView.new
    
    @controller = MockController.new
    @model      = MockModel.new
    
    @controller.set_value_for_key('mock_model', @model)
    
    @text_field.bind_to_object_with_key_path_options('text_value', @controller, 'mock_model.name', nil)
    @not_updated_text_field.bind_to_object_with_key_path_options('text_value', @controller, 'mock_model.name', nil)
  end
  
  describe "to a value at a path" do
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