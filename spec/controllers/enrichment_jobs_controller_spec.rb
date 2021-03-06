# The Supplejack Worker code is Crown copyright (C) 2014, New Zealand Government, 
# and is licensed under the GNU General Public License, version 3. 
# See https://github.com/DigitalNZ/supplejack_worker for details. 
# 
# Supplejack was created by DigitalNZ at the National Library of NZ
# and the Department of Internal Affairs. http://digitalnz.org/supplejack

require "spec_helper"

describe EnrichmentJobsController do

  let(:job) { double(:enrichment_job, save: true, update_attributes: true) }

  before(:each) do
    controller.stub(:authenticate_user!) { true }
  end
  
  describe "POST create" do
    it "initializes a new enrichment job" do
      post :create, enrichment_job: {strategy: "xml", file_name: "youtube.rb"}, format: "json"
      expect(assigns(:enrichment_job)).to be_a_new(EnrichmentJob)
      expect(assigns(:enrichment_job).strategy).to eq 'xml'
      expect(assigns(:enrichment_job).file_name).to eq 'youtube.rb'
    end

    it "should save the enrichment job" do
      EnrichmentJob.any_instance.should_receive(:save)
      post :create, enrichment_job: {strategy: "xml", file_name: "youtube.rb"}, format: "json"
      expect(assigns(:enrichment_job).strategy).to eq 'xml'
      expect(assigns(:enrichment_job).file_name).to eq 'youtube.rb'
    end
  end

  describe "#GET show" do
    it "finds the enrichment job" do
      EnrichmentJob.should_receive(:find).with("1") { job }
      get :show, id: 1, format: "json"
      assigns(:enrichment_job).should eq job
    end
  end

  describe "PUT Update" do
    before(:each) do
      EnrichmentJob.stub(:find).with("1") { job }
    end

    it "finds the enrichment job" do
      EnrichmentJob.should_receive(:find).with("1") { job }
      put :update, id: 1, format: "json"
      assigns(:enrichment_job).should eq job
    end

    it "should update the attributes" do
      job.should_receive(:update_attributes).with({"stop" => true})
      put :update, id: 1, enrichment_job: {stop: true}, format: "json"
    end
  end
end