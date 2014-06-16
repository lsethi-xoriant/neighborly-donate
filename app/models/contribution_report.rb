class ContributionReport
=begin
SELECT b.project_id,
 u.name,
 b.value,
 r.minimum_value,
 r.description,
 b.payment_method,
 b.payment_choice,
 fees.payment_service_fee,
 b.key,
 (b.created_at)::date AS created_at,
 (b.confirmed_at)::date AS confirmed_at,
 u.email,
 b.payer_email,
 b.payer_name,
 b.payer_document,
 u.address_street,
 u.address_complement,
 u.address_number,
 u.address_neighborhood AS address_neighbourhood,
 u.address_city,
 u.address_state,
 u.address_zip_code,
 b.state
((contributions b
  JOIN users u ON ((u.id = b.user_id)))
 LEFT JOIN rewards r ON ((r.id = b.reward_id)))
JOIN contributions_fees fees ON ((fees.id = b.id)))
WHERE ((b.state)::text = ANY (ARRAY[('confirmed'::character varying)::text, ('refunded'::character varying)::text, ('requested_refund'::character varying)::text]))
=end

  extend Enumerable
  include ActiveModel::Serialization

  attr_accessor :contribution

  delegate :reward, :user, :confirmed_at, :created_at, :key, :payer_document,
    :payer_email, :payer_name, :payment_choice, :payment_method,
    :payment_service_fee, :project_id, :state, :value, to: :contribution

  delegate :description, :minimum_value, to: :reward

  delegate :address_city, :address_complement, :address_neighborhood,
    :address_number, :address_state, :address_street, :address_zip_code,
    :email, :name, to: :user

  alias_method :address_neighbourhood, :address_neighborhood

  def self.each(&block)
    contributions.each do |contribution|
      block.call(contribution)
    end
  end

  def self.per_project(project)
    contributions(project)
  end

  def initialize(contribution)
    @contribution = contribution
  end

  def attributes
    {
      project_id: project_id,
      name: name,
      value: value,
      minimum_value: minimum_value,
      description: description,
      payment_method: payment_method,
      payment_choice: payment_choice,
      payment_service_fee: payment_service_fee,
      key: key,
      created_at: created_at,
      confirmed_at: confirmed_at,
      email: email,
      payer_email: payer_email,
      payer_name: payer_name,
      payer_document: payer_document,
      address_street: address_street,
      address_complement: address_complement,
      address_number: address_number,
      address_neighbourhood: address_neighbourhood,
      address_city: address_city,
      address_state: address_state,
      address_zip_code: address_zip_code,
      state: state
    }
  end

  private

  def self.contributions(project = nil)
    collection = project.try(:contributions) || Contribution
    @contributions ||= collection.with_state(:confirmed, :refunded, :requested_refund).
      map do |contribution|
      new(contribution)
    end
  end
end
