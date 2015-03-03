require_relative "../lib/template"

describe Template do
  let(:template) { Template.new "index" }
  let(:locals) { {test: 1, another: "test"} }

  describe "#assign_locals" do
    it "takes a hash and assigns the keys as local methods which return the values" do
      template.assign_locals locals
      expect(template.test).to eq 1
      expect(template.another).to eq "test"
    end
  end

  describe "#render" do
    it "assigns locals and returns the erb result" do
      expect(template).to receive(:assign_locals).with locals
      expect(template.erb).to receive(:result)
      template.render locals
    end
  end
end
