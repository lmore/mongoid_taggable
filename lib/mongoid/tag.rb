# encoding: UTF-8
class Tag
  include Mongoid::Document

  field :name, :type => String
  field :num, :type => Integer, :default => 1
  field :owner, :type => String
end
