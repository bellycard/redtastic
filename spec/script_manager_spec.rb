require 'spec_helper'

describe Redistat::ScriptManager do
  before do
    Redistat::ScriptManager.flush_scripts
    Redistat::ScriptManager.load_scripts('./spec/sample_scripts')
  end

  it 'allows the script to be called from the script manager' do
    expect(Redistat::ScriptManager.sample).to eq('bar')
  end

  it 'allows keys and argv to be passed into script' do
    keys = []
    argv = []
    keys << 'foo'
    argv << 'bar'
    expect(Redistat::ScriptManager.sample_with_args(keys, argv)).to eq('foobar')
  end

  it 'throws an error if it has not loaded the script being called' do
    expect { Redistat::ScriptManager.foo }.to raise_error(RuntimeError)
  end
end
