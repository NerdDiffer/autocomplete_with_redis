require 'spec_helper'

describe Dictionary::Search do
  attr_reader :dictionary

  subject { described_class.new(dictionary, 'bar') }

  before(:each) do
    stub_dictionary
  end

  describe '#search' do
    before(:each) do
      allow(subject).to receive(:max_results_count).and_return(2)
    end

    context '@start is nil' do
      before(:each) do
        allow(subject).to receive(:starting_point).and_return(nil)
      end

      it 'calls #starting_point' do
        expect(subject).to receive(:starting_point).and_return(nil)
        subject.send(:search)
      end
      it 'sets value of @start to #starting_point' do
        expect(subject.start).to be_nil
        subject.send(:search)
      end
      it 'returns [] when @start is nil' do
        expect(subject.send(:search)).to eq []
      end
    end

    context 'when @start is NOT nil' do
      before(:each) do
        allow(subject).to receive(:starting_point).and_return(0)
        allow(subject).to receive(:iterate)
      end

      context 'when result of #iterate is an early return trigger' do
        it 'breaks the loop' do
          allow(subject).to receive(:early_trigger?).and_return(true)
          expect(subject).to receive(:iterate).exactly(1).times
          subject.send(:search)
        end
      end
      context 'when result of #iterate is NOT an early return trigger' do
        it 'does NOT call for a break' do
          allow(subject)
            .to receive(:num_results_less_than_max?)
            .and_return(true, true, false)
          allow(subject).to receive(:early_trigger?).and_return(false)
          expect(subject).to receive(:iterate).exactly(2).times
          subject.send(:search)
        end
      end
    end
  end

  describe '#starting_point' do
    before(:each) do
      allow(subject).to receive(:set_key).and_return('bar')
      allow(subject).to receive(:_query).and_return('foo')
    end

    it 'calls #zrank on redis client with these args' do
      expect(subject.redis).to receive(:zrank).with('bar', 'foo')
      subject.send(:starting_point)
    end
  end

  describe '#num_results_less_than_max?' do
    let(:results) { [:foo] }

    before(:each) do
      allow(subject).to receive(:results).and_return(results)
      allow(results).to receive(:length).and_return(1)
    end

    it 'is true' do
      allow(subject).to receive(:max_results_count).and_return(2)
      expect(subject.send(:num_results_less_than_max?)).to be_truthy
    end

    it 'is false' do
      allow(subject).to receive(:max_results_count).and_return(0)
      expect(subject.send(:num_results_less_than_max?)).to be_falsey
    end
  end

  describe '#early_trigger?' do
    before(:each) do
      allow(subject).to receive(:early_return_trigger).and_return(:foo)
    end

    it 'returns true if result is equal to early_return_trigger' do
      actual = subject.send(:early_trigger?, :foo)
      expect(actual).to be_truthy
    end
    it 'returns false if result is NOT equal to early_return_trigger' do
      actual = subject.send(:early_trigger?, :bar)
      expect(actual).to be_falsey
    end
  end

  describe '#iterate' do
    it 'calls #next_batch!' do
      allow(subject).to receive(:empty?).and_return(true)
      expect(subject).to receive(:next_batch!)
      subject.send(:iterate)
    end

    context 'when the batch is empty' do
      it 'returns value of #early_return_trigger' do
        allow(subject).to receive(:next_batch!)
        allow(subject).to receive(:empty?).and_return(true)
        allow(subject).to receive(:early_return_trigger).and_return(:foobar)
        actual = subject.send(:iterate)
        expect(actual).to eq :foobar
      end
    end

    context 'when batch is NOT empty' do
      before(:each) do
        allow(subject).to receive(:next_batch!)
        allow(subject).to receive(:empty?).and_return(false)
      end

      it 'iterates through the batch' do
        allow(subject).to receive(:batch).and_return([])
        expect(subject.batch).to receive(:each)
        subject.send(:iterate)
      end

      context 'inside the loop' do
        before(:each) do
          allow(subject).to receive(:batch).and_return([:foo, :bar])
          allow(subject).to receive(:process).and_return(true)
        end

        it 'calls #process' do
          expect(subject).to receive(:process).with(:foo).with(:bar)
          subject.send(:iterate)
        end
      end
    end
  end

  describe '#next_batch!' do
    before(:each) do
      allow(subject).to receive(:set_key).and_return('foo')
      allow(subject).to receive(:range_len).and_return(10)
      allow(subject).to receive(:start).and_return(0)
      allow(subject.redis)
        .to receive(:zrange)
        .and_return(%w(foo bar))
    end
    after(:each) do
      subject.instance_eval { @batch = nil }
      subject.instance_eval { @start = nil }
    end

    context '@batch & the redis client' do
      before(:each) do
        subject.instance_eval { @batch = %w(foo) }
        subject.instance_eval { @start = 0 }
      end

      it 'calls zrange on the redis client' do
        expect(subject.redis).to receive(:zrange).with(subject.set_key, 0, 9)
        subject.send(:next_batch!)
      end
      it 'sets a value for the @batch variable' do
        subject.send(:next_batch!)
        expect(subject.batch).to eq %w(foo bar)
      end
    end

    context '@start' do
      before(:each) do
        subject.instance_eval { @batch = %w(foo) }
        subject.instance_eval { @start = 10 }
        allow(subject).to receive(:start).and_return(0, 0, subject.range_len)
      end

      it 'changes value of @start by 10' do
        expect { subject.send(:next_batch!) }
          .to change { subject.start }
          .by(subject.range_len)
      end
    end
  end

  describe '#empty?' do
    it 'calls #empty? on the input' do
      input = 'foo'
      expect(input).to receive(:empty?)
      subject.send(:empty?, input)
    end
  end

  describe '#process' do
    let(:input) { 'foo' }

    before(:each) do
      allow(subject).to receive(:prepare_range)
    end

    context 'whether or not the result of #not_matching?' do
      before(:each) do
        allow(subject).to receive(:not_matching?)#.and_return(false)
        allow(subject).to receive(:ok_to_append?)#.and_return(false)
      end

      it 'calls #prepare_range' do
        expect(subject).to receive(:prepare_range)
        subject.send(:process, input)
      end
    end

    context 'if #not_matching? is true' do
      before(:each) do
        allow(subject).to receive(:not_matching?).and_return(true)
      end

      it 'returns' do
        actual = subject.send(:process, input)
        expect(actual).to be_nil
      end
      it 'does not call #append?' do
        expect(subject).not_to receive(:append?)
        subject.send(:process, input)
      end
    end

    context 'if #not_matching? is false' do
      before(:each) do
        allow(subject).to receive(:prepare_range)
        allow(subject).to receive(:not_matching?).and_return(false)
      end
      after(:each) do
        subject.send(:process, input)
      end

      it 'calls #append?' do
        allow(subject).to receive(:append?).and_return(false)
        expect(subject).to receive(:append?).with(input)
      end
      context 'if #append? is true' do
        it 'calls #append!' do
          allow(subject).to receive(:append?).and_return(true)
          expect(subject).to receive(:append!).with(input)
        end
      end
    end
  end

  describe '#prepare_range' do
    let(:input) { 'foo' }

    before(:each) do
      allow(input).to receive(:length).and_return(3)
      allow(subject).to receive(:_query).and_return('foobar')
      allow(subject._query).to receive(:length).and_return(6)
    end

    it 'the input receives .length' do
      expect(input).to receive(:length)
      subject.send(:prepare_range, input)
    end
    it 'the query receives .length' do
      expect(subject._query).to receive(:length)
      subject.send(:prepare_range, input)
    end
    it 'returns a range with the smaller of the two lengths' do
      actual = subject.send(:prepare_range, input)
      expect(actual).to eq((0...3))
    end
  end

  describe '#not_matching?' do
    let(:range) { (0...6) }
    let(:input) { 'foo' }

    before(:each) do
      allow(input).to receive(:downcase).and_return(input)
      allow(subject).to receive(:_query).and_return('foobar')
    end

    it 'downcases the input' do
      expect(input).to receive(:downcase)
      subject.send(:not_matching?, input, range)
    end
    it 'calls the [] method with the range on the input' do
      expect(input).to receive(:[]).with(range)
      subject.send(:not_matching?, input, range)
    end
    it 'calls the [] method with the range on the query' do
      expect(subject._query).to receive(:[]).with(range)
      subject.send(:not_matching?, input, range)
    end
    it 'returns true when entry will NOT match the query' do
      non_matching_input = 'football'
      actual = subject.send(:not_matching?, non_matching_input, range)
      expect(actual).to be_truthy
    end
    it 'returns false when entry will match the query' do
      matching_input = 'foobar'
      actual = subject.send(:not_matching?, matching_input, range)
      expect(actual).to be_falsey
    end
  end

  describe '#append?' do
    context 'true' do
      before(:each) do
        allow(subject).to receive(:last_value_is_glob?).and_return(true)
        allow(subject).to receive(:num_results_not_eq_to_max?).and_return(true)
      end

      it 'is true when both methods return true' do
        expect(subject.send(:append?, 'foo')).to be_truthy
      end
    end

    context 'false' do
      after(:each) do
        expect(subject.send(:append?, 'foo')).to be_falsey
      end

      it 'is otherwise false' do
        allow(subject).to receive(:last_value_is_glob?).and_return(false)
        allow(subject).to receive(:num_results_not_eq_to_max?).and_return(true)
      end
      it 'is otherwise false' do
        allow(subject).to receive(:last_value_is_glob?).and_return(true)
        allow(subject).to receive(:num_results_not_eq_to_max?).and_return(false)
      end
      it 'is otherwise false' do
        allow(subject).to receive(:last_value_is_glob?).and_return(false)
        allow(subject).to receive(:num_results_not_eq_to_max?).and_return(false)
      end
    end
  end

  describe '#last_value_is_glob?' do
    it 'the input receives [] with a range' do
      input = 'foobar'
      expect(input).to receive(:[]).with((-1..-1))
      subject.send(:last_value_is_glob?, input)
    end
    it 'returns true when last value in input is "*"' do
      actual = subject.send(:last_value_is_glob?, 'foo*')
      expect(actual).to be_truthy
    end
    it 'otherwise returns false' do
      actual = subject.send(:last_value_is_glob?, 'foo')
      expect(actual).to be_falsey
    end
  end

  describe '#num_results_not_eq_to_max?' do
    before(:each) do
      allow(subject).to receive(:max_results_count).and_return(1)
    end

    it 'returns true when results.length != max_results_count' do
      allow(subject).to receive(:results).and_return([:foo, :bar])
      actual = subject.send(:num_results_not_eq_to_max?)
      expect(actual).to be_truthy
    end
    it 'otherwise returns false' do
      allow(subject).to receive(:results).and_return([:foo])
      actual = subject.send(:num_results_not_eq_to_max?)
      expect(actual).to be_falsey
    end
  end

  describe '#append!' do
    let(:input) { 'foo*' }

    context 'the input' do
      it 'receives [] with a range' do
        expect(input).to receive(:[]).with(an_instance_of(Range))
        subject.send(:append!, input)
      end
    end
    it 'adds a value to results' do
      allow(input).to receive(:[]).with(an_instance_of(Range)).and_return('foo')
      expect(subject.results).to receive(:<<).with('foo')
      subject.send(:append!, input)
    end
  end

  private

  def stub_dictionary
    redis = Redis.new
    @dictionary = Dictionary.new(TEST_KEY)
    allow(dictionary).to receive(:set_key).and_return(TEST_KEY)
    allow(dictionary).to receive(:redis).and_return(redis)
    allow(dictionary).to receive(:refresh).and_return(true)
    allow(dictionary).to receive(:search).and_return(true)
  end
end
