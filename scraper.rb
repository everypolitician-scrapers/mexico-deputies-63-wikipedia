#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    (uninominal_members + proportional_members).each do |mem|
      party = parties.find { |party| party[:image] == mem[:party_image] } || {}
      mem[:party] = party[:name]
      mem[:party_id] = party[:id]
    end
  end

  field :parties do
    @parties ||= party_table.xpath('.//tr[td[a]]').map { |tr| fragment(tr => PartyRow).to_h }
  end

  private

  def party_table
    noko.xpath('//h3[contains(.,"Número de Diputados por partido político")]/following::table[1]')
  end

  def uninominal_table
    noko.xpath('//h3[contains(.,"Diputados por distrito uninominal")]/following::table[1]')
  end

  def uninominal_members
    uninominal_table.xpath('.//tr[td]').map { |tr| data = fragment(tr => LeftMemberRow).to_h } +
    uninominal_table.xpath('.//tr[td]').map { |tr| data = fragment(tr => RightMemberRow).to_h }
  end

  def proportional_table
    noko.xpath('//h3[contains(.,"Diputados por representación proporcional")]/following::table[1]')
  end

  def proportional_members
    proportional_table.xpath('.//tr[td]').map { |tr| data = fragment(tr => ProportionalLeftMemberRow).to_h } +
    proportional_table.xpath('.//tr[td]').map { |tr| data = fragment(tr => ProportionalRightMemberRow).to_h }
  end
end

class LeftMemberRow < Scraped::HTML
  field :name do
    name_field.css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    name_field.css('a').map { |a| a.attr('wikidata') }.first
  end

  field :area do
    [state, district].join(" ")
  end

  field :area_id do
    district_field.css('a/@wikidata').map(&:text).first
  end

  field :party_image do
    party_field.css('img/@alt').map(&:text).first
  end

  private

  def tds
    noko.css('td')
  end

  def offset
    0
  end

  def state
    state_field.css('a').map(&:text).map(&:tidy).first
  end

  def district
    district_field.css('a').map(&:text).map(&:tidy).first
  end

  def state_field
    tds[0 + offset]
  end

  def district_field
    tds[1 + offset]
  end

  def name_field
    tds[2 + offset]
  end

  def party_field
    tds[3 + offset]
  end
end

class RightMemberRow < LeftMemberRow
  def offset
    4
  end
end

class ProportionalLeftMemberRow < LeftMemberRow
  field :area do
    district_field.text.tidy
  end

  field :area_id do
    nil
  end

  def offset
    -1
  end
end

class ProportionalRightMemberRow < ProportionalLeftMemberRow
  def offset
    2
  end
end

class PartyRow < Scraped::HTML
  field :image do
    tds[0].css('img/@alt').map(&:text).first
  end

  field :name do
    tds[1].css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    tds[1].css('a/@wikidata').map(&:text).first
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://es.wikipedia.org/wiki/LXIII_Legislatura_del_Congreso_de_la_Uni%C3%B3n_de_M%C3%A9xico'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name area])
