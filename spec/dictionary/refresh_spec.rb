require 'spec_helper'

describe Dictionary::Refresh do
  subject { Dictionary.new(TEST_KEY) }
  let(:name) { 'bar' }

  describe '#populate_set' do
    let(:file) { double('File', each_line: true) }

    before(:each) do
      allow(File).to receive(:new).and_return(file)
      allow(file)
        .to receive(:each_line)
        .and_yield('alpha')
        .and_yield('beta')
      allow(subject).to receive(:process_line).and_return(true)
    end
    after(:each) do
      subject.send(:populate_set)
    end

    it 'creates a new File object' do
      expect(File).to receive(:new).with(subject.file_name)
    end
    it 'calls #each_line on the File object' do
      expect(file).to receive(:each_line)
    end
    it 'calls #process_line' do
      expect(subject).to receive(:process_line).with('alpha').with('beta')
    end
  end

  describe '#process_line' do
    let(:range) { (1..3) }

    before(:each) do
      allow(name).to receive(:strip!).and_return(name)
      allow(subject).to receive(:prepare_range).and_return(range)
      allow(subject).to receive(:add_to_set!).and_return(true)
      allow(subject).to receive(:append_with_glob_member!).and_return(true)
    end
    after(:each) do
      subject.send(:process_line, name)
    end

    it 'calls #strip! on the name' do
      expect(name).to receive(:strip!)
    end
    it 'calls #prepare_range' do
      expect(subject).to receive(:prepare_range).with(name)
    end
    it 'calls #each on the range' do
      expect(range).to receive(:each)
    end
    it 'calls #add_to_set!' do
      expect(subject)
        .to receive(:add_to_set!)
        .exactly(range.size).times
    end
    it 'calls #append_with_glob_member!' do
      expect(subject).to receive(:append_with_glob_member!)
    end
  end

  describe '#prepare_range' do
    it 'returns this range' do
      allow(name).to receive(:length).and_return(3)
      actual = subject.send(:prepare_range, name)
      expect(actual).to eq (1..3)
    end
  end

  describe '#delete_set_key!' do
    it 'calls #del on redis client' do
      allow(subject.redis).to receive(:del)
      expect(subject.redis).to receive(:del).with(subject.set_key)
      subject.send(:delete_set_key!)
    end
  end

  describe '#add_to_set!' do
    let(:index) { 2 }
    let(:range) { (0...index) }
    let(:member) { 'ba' }

    before(:each) do
      allow(name).to receive(:[]).with(range).and_return(member)
      allow(subject.redis).to receive(:zadd).and_return(true)
    end
    after(:each) do
      subject.send(:add_to_set!, index, name)
    end

    it 'calls [] on the input' do
      expect(name).to receive(:[]).with(range)
    end
    it 'calls "zadd" on redis client' do
      expect(subject.redis).to receive(:zadd).with(subject.set_key, 0, member)
    end
  end

  describe '#append_with_glob_member!' do
    let(:member) { 'bar*' }

    before(:each) do
      allow(name).to receive(:+).with('*').and_return(member)
      allow(subject.redis).to receive(:zadd)
    end
    after(:each) do
      subject.send(:append_with_glob_member!, name)
    end

    it 'puts a "*" at end of the name' do
      expect(name).to receive(:+).with('*')
    end
    it 'calls "zadd" on redis client' do
      expect(subject.redis).to receive(:zadd).with(subject.set_key, 0, member)
    end
  end
end
