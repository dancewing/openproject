#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

class ActivitiesController < ApplicationController
  menu_item :activity
  before_action :find_optional_project,
                :verify_activities_module_activated

  accept_key_auth :index

  def index
    @days = Setting.activity_days_default.to_i

    if params[:from]
      begin; @date_to = params[:from].to_date + 1.day; rescue; end
    end

    @date_to ||= User.current.today + 1.day
    @date_from = @date_to - @days
    @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_work_packages? : (params[:with_subprojects] == '1')
    @author = (params[:user_id].blank? ? nil : User.active.find(params[:user_id]))

    @activity = Activities::Fetcher.new(User.current,
                                        project: @project,
                                        with_subprojects: @with_subprojects,
                                        author: @author)

    set_activity_scope

    events = @activity.events(@date_from, @date_to)

    respond_to do |format|
      format.html do
        @events_by_day = events.group_by { |e| e.event_datetime.in_time_zone(User.current.time_zone).to_date }
        render layout: !request.xhr?
      end
      format.atom do
        title = t(:label_activity)
        if @author
          title = @author.name
        elsif @activity.scope.size == 1
          title = t("label_#{@activity.scope.first.singularize}_plural")
        end
        render_feed(events, title: "#{@project || Setting.app_title}: #{title}")
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    op_handle_warning "Failed to find all resources in activities: #{e.message}"
    render_404 I18n.t(:error_can_not_find_all_resources)
  end

  private

  def verify_activities_module_activated
    render_403 if @project && !@project.module_enabled?('activity')
  end

  def set_activity_scope
    if params[:apply]
      @activity.scope_select { |t| !params["show_#{t}"].nil? }
    elsif session[:activity]
      @activity.scope = session[:activity]
    else
      @activity.scope = (@author.nil? ? :default : :all)
    end

    session[:activity] = @activity.scope
  end
end
