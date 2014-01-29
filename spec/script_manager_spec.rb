require 'spec_helper'

describe Redtastic::ScriptManager do
  before do
    Redtastic::ScriptManager.flush_scripts
    Redtastic::ScriptManager.load_scripts('./spec/sample_scripts')
  end

  it 'allows the script to be called from the script manager' do
    expect(Redtastic::ScriptManager.sample).to eq('bar')
  end

  it 'allows keys and argv to be passed into script' do
    keys = []
    argv = []
    keys << 'foo'
    argv << 'bar'
    expect(Redtastic::ScriptManager.sample_with_args(keys, argv)).to eq('foobar')
  end

  it 'throws an error if it has not loaded the script being called' do
    expect { Redtastic::ScriptManager.foo }.to raise_error(RuntimeError)
  end
end
