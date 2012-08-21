require 'test_helper'

class ProjectsControllerTest < ActionController::TestCase
  signed_in_admin_context do
    setup do
      @project = Project.make(:customer => @user.customer, :company => @user.company)
    end

    should "get list page" do
      get :index
      assert_response :success
    end

    should "get new project page" do
      get :new
      assert_response :success
    end

    should "get project view page" do
      get :show, :id => @project.id
      assert_response :success
    end

    should "create project and copy project permissions" do
      project_hash = {
        name: 'New Project',
        description: 'Some description',
        customer_id: @user.customer.id,
        company_id: @user.company.id
      }
      assert_difference("Project.count", +1) do
        post :create, {
          project: project_hash,
          copy_project_id: @project.id
        }
      end
      filter = TaskFilter.where(:name => project_hash[:name]).first
      assert filter
      assert filter.qualifiers.detect {|q| q.qualifiable.name == project_hash[:name]}
      assert filter.qualifiers.detect {|q| q.qualifiable == @user.company.statuses.first }
      assert_equal 3, assigns[:project].project_permissions.size
      assert_redirected_to :action => :index
    end

    should "get edit project page" do
      get :edit, :id => @project.id
      assert_response :success
    end

    should "update project" do
      post :update, {:project=>{:name=>"New Project Name", :description=>"New Project Description",
                     :customer_id=>@user.customer.id},
                     :id=>@project.id,
                     :customer=>{:name=>@user.customer.name}}
      assert_equal "New Project Name", assigns[:project].name
      assert_equal "New Project Description", assigns[:project].description
      assert_redirected_to :action=> "index"
    end

    should "complete project" do
      post :complete, {:id => @project.id}
      assert_not_nil @project.reload.completed_at
      assert_redirected_to edit_project_path(@project)
    end

    should "revert project" do
      post :revert, {:id => projects(:completed_project).id}
      assert_nil projects(:completed_project).reload.completed_at
      assert_redirected_to edit_project_path(projects(:completed_project))
    end
    context "destroy project" do
      setup do
        task = Task.make(:project => @project, :company => @user.company)
        @project.sheets << Sheet.make(:user => @user, :task => task)
        @project.work_logs << WorkLog.make(:user => @user)
      end

      context "without tasks" do
        setup do
          other = Project.where("id !=?", @project.id).first
          @project.tasks.each{ |task|
            task.project=other
            task.save!
          }
        end
        should "remove project and its worklogs, tasks, pages, milestones, sheets, project permissions" do
          assert_difference("Project.count", -1) do
            delete :destroy, :id => @project.id
          end
          assert_equal 0, Task.where(:project_id => @project.id).count
          assert_equal 0, WorkLog.where(:project_id => @project.id).count
          assert_equal 0, Milestone.where(:project_id => @project.id).count
          assert_equal 0, Sheet.where(:project_id => @project.id).count
          assert_equal 0, ProjectPermission.where(:project_id => @project.id).count
          assert_redirected_to :action=> "index"
        end
      end
      context "with tasks" do
        should "reject destroy action" do
          assert_no_difference("Project.count") do
            delete :destroy, :id => @project.id
          end
          assert_not_equal 0, Task.where(:project_id => @project.id).count
          assert_not_equal 0, WorkLog.where(:project_id => @project.id).count
          assert_not_equal 0, Milestone.where(:project_id => @project.id).count
          assert_not_equal 0, Sheet.where(:project_id => @project.id).count
          assert_not_equal 0, ProjectPermission.where(:project_id => @project.id).count
        end
      end
    end
  end
end
