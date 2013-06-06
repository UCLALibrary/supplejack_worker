class AbstractJob
  include Mongoid::Document
  include Mongoid::Timestamps

  include ActiveModel::SerializerSupport

  index status: 1

  field :start_time,            type: DateTime
  field :end_time,              type: DateTime
  field :records_count,         type: Integer, default: 0
  field :processed_count,       type: Integer, default: 0
  field :throughput,            type: Float
  field :status,                type: String, default: "active"
  field :user_id,               type: String
  field :parser_id,             type: String
  field :version_id,            type: String
  field :environment,           type: String
  field :invalid_records_count, type: Integer,  default: 0
  field :failed_records_count,  type: Integer,  default: 0
  field :posted_records_count,  type: Integer,  default: 0
  field :parser_code,           type: String
  field :last_posted_record_id,  type: String  

  embeds_many :invalid_records
  embeds_many :failed_records
  embeds_one :harvest_failure

  belongs_to :harvest_schedule

  validates_presence_of   :parser_id, :environment

  scope :disposable, -> { lt(created_at: Time.now-7.days).gt(created_at: Time.now-21.days) }

  def self.search(params)
    search_params = params.try(:dup).try(:symbolize_keys) || {}
    valid_fields = [:status, :environment, :parser_id]

    page = search_params.delete(:page) || 1
    amount = search_params.delete(:limit) || nil

    search_params.delete_if {|key, value| !valid_fields.include?(key) }

    scope = self.page(page.to_i).desc(:start_time)

    search_params.each_pair do |attribute, value|
      if value.is_a?(Array)
        scope = scope.in(attribute => value)
        search_params.delete(attribute)
      end
    end

    scope = scope.where(search_params)
    scope = scope.limit(amount.to_i) if amount
    scope
  end

  def self.clear_raw_data
    self.disposable.each(&:clear_raw_data)
  end

  def enqueue
    raise NotImplementedError.new("All subclasses of AbstractJob must define a #enqueue method.")
  end

  def parser
    return @parser if @parser.present?
    if version_id.present?
      @parser = ParserVersion.find(self.version_id, params: {parser_id: self.parser_id})
    elsif environment.present? and not preview?
      version = ParserVersion.find(:one, from: :current, params: {parser_id: self.parser_id, environment: self.environment})
      version.parser_id = self.parser_id
      self.version_id = version.id if version.present?
      @parser = version
    else
      parser = Parser.find(self.parser_id)
      parser.content = self.parser_code if self.parser_code.present?
      @parser = parser
    end
  end

  def required_enrichments
    self.parser.enrichment_definitions.dup.keep_if {|name, options| options[:required_for_active_record] }.keys
  end

  def start!
    self.status = "active"
    self.start_time = Time.now
    self.records_count = 0
    self.processed_count = 0
    self.save
  end

  def finish!
    self.status = "finished"
    self.end_time = Time.now
    self.calculate_throughput
    self.calculate_errors_count
    self.save
  end

  def active?
    self.status == "active"
  end

  def finished?
    self.status == "finished"
  end

  def stopped?
    self.status == "stopped"
  end

  def test?
    self.environment == "test"
  end

  def preview?
    self.environment == "preview"
  end

  def calculate_throughput
    if self.duration.to_f > 0
      self.throughput = self.records_count.to_f / self.duration.to_f
    end
  end

  def duration
    return nil unless self.start_time && self.end_time
    self.end_time.to_i - self.start_time.to_i
  end

  def calculate_errors_count
    self.invalid_records_count = self.invalid_records.count
    self.failed_records_count = self.failed_records.count
  end

  def total_errors_count
    self.invalid_records.count + self.failed_records.count
  end

  def errors_over_limit?
    self.total_errors_count > 100
  end

  def clear_raw_data
    self.invalid_records.destroy_all
    self.failed_records.destroy_all
  end

  def increment_records_count!
    self.records_count += 1
    self.save
  end

  def increment_processed_count!
    self.processed_count += 1
    self.save
  end
end