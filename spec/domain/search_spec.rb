RSpec.describe Search do
  def node(content_id)
    FactoryGirl.create(:content_item, content_id: content_id)
  end

  def edge(from:, to:, type:)
    FactoryGirl.create(
      :link,
      source_content_id: from,
      target_content_id: to,
      link_type: type,
    )
  end

  before do
    node("id1")
    node("id2")
    node("id3")
    node("org1")
    node("org2")
    node("policy1")

    edge(from: "id1", to: "org1", type: "organisations")
    edge(from: "id2", to: "org2", type: "organisations")
    edge(from: "id3", to: "org1", type: "organisations")
    edge(from: "id2", to: "policy1", type: "policies")
    edge(from: "id3", to: "policy1", type: "policies")
  end

  let(:content_ids) do
    subject.execute
    subject.content_items.map(&:content_id)
  end

  it "can filter by a single type and single target" do
    subject.filter_by(link_type: "organisations", target_content_ids: "org1")
    expect(content_ids).to eq %w(id1 id3)
  end

  it "can filter by a single type and multiple targets" do
    subject.filter_by(link_type: "organisations", target_content_ids: %w(org1 org2))
    expect(content_ids).to eq %w(id1 id2 id3)
  end

  it "can filter by multiple types for a single target" do
    subject.filter_by(link_type: "organisations", target_content_ids: "org1")
    subject.filter_by(link_type: "policies", target_content_ids: "policy1")

    expect(content_ids).to eq %w(id3)
  end

  it "can filter by multiple types and multiple targets" do
    subject.filter_by(link_type: "organisations", target_content_ids: %w(org1 org2))
    subject.filter_by(link_type: "policies", target_content_ids: "policy1")

    expect(content_ids).to eq %w(id2 id3)
  end

  it "returns no results if there is no target for the type" do
    subject.filter_by(link_type: "policies", target_content_ids: "org1")
    expect(content_ids).to be_empty
  end

  it "raises an error if a filter already exists for a type" do
    subject.filter_by(link_type: "organisations", target_content_ids: "org1")

    expect { subject.filter_by(link_type: "organisations", target_content_ids: "org1") }
      .to raise_error(DuplicateFilterError)
  end
end
