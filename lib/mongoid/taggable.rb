# Copyright (c) 2010 Wilker Lúcio <wilkerlucio@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongoid::Taggable
  def self.included(base)
    # create fields for tags and index it
    base.field :tags_array, :type => Array, :default => []
    base.index({ tags_array: 1 }, { background: true })

    # add callback to save tags index
    base.after_save do |document|
      if document.tags_array_changed?
        document.save_tags_index
      end
    end

	base.after_destroy do |document|
	  document.reduce_tags_index
	end

    # extend model
    base.extend         ClassMethods
    base.send :include, InstanceMethods
    base.send :attr_accessor, :raw_tags_array

    # enable indexing as default
    #base.enable_tags_index!
  end

  module ClassMethods
    # returns an array of distinct ordered list of tags defined in all documents

    def tagged_with(tag)
      self.any_in(:tags_array => [tag])
    end

    def tagged_with_all(*tags)
      self.all_in(:tags_array => tags.flatten)
    end

    def tagged_with_any(*tags)
      self.any_in(:tags_array => tags.flatten)
    end

    def tags
      Tag.where(:owner => self.to_s)
    end

    def tags_separator(separator = nil)
      @tags_separator = separator if separator
      @tags_separator || ','
    end
  end

  module InstanceMethods
    def tags
      (self.tags_array || []).join("#{self.class.tags_separator.split('|').first} ")
    end

    def tags=(tags)
	  @raw_tags_array = self.tags_array || []
      self.tags_array = tags.split(%r{["#{self.class.tags_separator}"]\s*}).map(&:strip).reject(&:blank?)
    end

    def save_tags_index
	  target = self
	  reduce = self.raw_tags_array - self.tags_array
	  increase = self.tags_array - self.raw_tags_array
	  reduce.each do |name|
		tag = Tag.where(:owner => target.class).where(:name => name).last
		return unless tag
		tag.num > 1 ?
		  tag.update_attribute(:num, tag.num-1) :
		  tag.destroy
	  end
	  increase.each do |name|
		tag = Tag.where(:owner => target.class).where(:name => name).last
		tag.nil? ?
		  Tag.create(:name => name, :owner => target.class) :
		  tag.update_attribute(:num, tag.num+1)
	  end
    end

	def reduce_tags_index
	  target = self
	  self.tags_array.each do |name|
		tag = Tag.where(:owner => target.class).where(:name => name).last
		tag.num > 1 ?
		  tag.update_attribute(:num, tag.num-1) :
		  tag.destroy
	  end
	end
  end
end
