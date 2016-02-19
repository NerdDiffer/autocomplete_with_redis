require 'spec_helper'

describe Dictionary do
  subject { Dictionary.new(TEST_KEY) }

  describe '#refresh' do
    before(:each) do
      allow(subject).to receive(:populate_set)
      allow(subject).to receive(:puts)
    end
    after(:each) do
      subject.refresh
    end

    context 'calling #delete_set_key!' do
      context 'when Redis finds a key named by Dictionary object' do
        before(:each) do
          allow(subject.redis).to receive(:exists).and_return(true)
          allow(subject).to receive(:delete_set_key!)
        end

        it 'calls #delete_set_key!' do
          expect(subject).to receive(:delete_set_key!)
        end
      end

      context 'when Redis does NOT find a key named by Dictionary object' do
        before(:each) do
          allow(subject.redis).to receive(:exists).and_return(false)
        end

        it 'does not call #delete_set_key!' do
          expect(subject).not_to receive(:delete_set_key!)
        end
      end
    end

    it 'calls #populate_set' do
      allow(subject.redis).to receive(:exists).and_return(false)
      expect(subject).to receive(:populate_set)
    end
  end

  describe '#search' do
    it 'calls for a new Search object' do
      query = 'bar'
      allow(Dictionary::Search).to receive(:new).with(subject, query, 50)
      expect(Dictionary::Search).to receive(:new).with(subject, query, 50)
      subject.search(query)
    end

    context 'case-insensitive searching' do
      let(:sorted_set) do
        ['A', 'Al', 'All', 'Alli', 'Allis', 'Alliso', 'Allison', 'Allison*', 'a', 'al', 'all', 'alla', 'alla*', 'alle', 'allee', 'alleen', 'alleen*', 'alleg', 'allegr', 'allegra', 'allegra*', 'allen', 'allene', 'allene*', 'alli', 'alli*', 'allia', 'allian', 'alliano', 'allianor', 'allianora', 'allianora*', 'allie', 'allie*', 'allin', 'allina', 'allina*', 'allis', 'allis*', 'alliss', 'allissa', 'allissa*', 'allix', 'allix*', 'alls', 'allsu', 'allsun', 'allsun*', 'allx', 'allx*', 'ally', 'ally*', 'allyc', 'allyce', 'allyce*', 'allyn', 'allyn*', 'allys', 'allys*', 'allyso', 'allyson', 'allyson*']
      end
      let(:expected_results) do
        %w(Allison alli allianora allie allina allis allissa allix)
      end

      before(:each) do
        allow(subject.redis).to receive(:zrank).and_return(0)
        allow(subject.redis).to receive(:zrange).and_return(sorted_set, [])
      end

      context 'searching with capitalized term' do
        it 'returns expected results' do
          query = 'Alli'
          search = subject.search(query)
          expect(search.results).to eq expected_results
        end
      end
      context 'searching with lower-cased term' do
        it 'returns expected results' do
          query = 'alli'
          search = subject.search(query)
          expect(search.results).to eq expected_results
        end
      end
    end
  end
end
