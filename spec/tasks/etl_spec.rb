RSpec.describe 'rake etl:master', type: task do
  it "calls Etl::Master::MasterProcessor.process" do
    processor = class_double(Etl::Master::MasterProcessor, process: true).as_stubbed_const
    expect(processor).to receive(:process)

    Rake::Task['etl:master'].invoke
  end
end
