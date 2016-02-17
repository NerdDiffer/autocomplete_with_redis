require 'dictionary'

describe Dictionary do
  subject { Dictionary.new('foo') }

  describe '#search' do
    context 'case-insensitive' do
      let(:sorted_set) do
        ['A', 'Al', 'All', 'Alli', 'Allis', 'Alliso', 'Allison', 'Allison*', 'a', 'al', 'all', 'alla', 'alla*', 'alle', 'allee', 'alleen', 'alleen*', 'alleg', 'allegr', 'allegra', 'allegra*', 'allen', 'allene', 'allene*', 'alli', 'alli*', 'allia', 'allian', 'alliano', 'allianor', 'allianora', 'allianora*', 'allie', 'allie*', 'allin', 'allina', 'allina*', 'allis', 'allis*', 'alliss', 'allissa', 'allissa*', 'allix', 'allix*', 'alls', 'allsu', 'allsun', 'allsun*', 'allx', 'allx*', 'ally', 'ally*', 'allyc', 'allyce', 'allyce*', 'allyn', 'allyn*', 'allys', 'allys*', 'allyso', 'allyson', 'allyson*']
      end
      let(:expected_results) do
        %w(Allison alli allianora allie allina allis allissa allix)
      end

      before(:each) do
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
