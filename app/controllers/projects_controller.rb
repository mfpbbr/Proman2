class ProjectsController < ApplicationController

  skip_before_filter :login_required, :only => ["index","by_discipline","by_centre","by_supervisor"]
  require_role ["admin", "coordinator", "staff"], :for => ["new", "create", "edit", "update", "destroy"]
  before_filter :can_edit, :only => ["create", "edit", "update", "destroy"]

  resources_controller_for :projects


  helper_method :can_edit

  # Non standard methods

  def allocate
    @projects = Project.find_by_sql "SELECT * FROM projects WHERE id NOT IN (SELECT project_id FROM students WHERE project_id IS NOT NULL)"
    @students = Student.find_by_sql "SELECT * FROM students WHERE project_id IS NULL OR project_id = 0 ORDER BY grade DESC"
    @assigned = []
    @ass_students = []
    @nass_students = []
    @students.each do |s|
      @applied = Student.find_by_sql "SELECT p.title, p.id AS project_id, sp.wish, CONCAT(s.first_name, ' ', s.last_name) AS fname, s.id AS student_id FROM projects AS p, users AS s, wishes AS sp WHERE  sp.project_id = p.id AND sp.student_id = s.id AND sp.student_id=#{s.id} ORDER BY sp.wish ASC"
      assigned = false
      @applied.each do |app|
        if !@assigned.include?(app.project_id) && !assigned
          @assigned.push(app.project_id)
          @ass_students.push(app.student_id)
          assigned = true
        end
      end
      unless assigned
        @nass_students.push(s.id)
      end
    end
    i = 0
    @assigned.each do |p|
      #@ass_students[i] = (Project.find p).title
      @student = Student.find(@ass_students[i])
      s = {}
      s[:student] = {}
      s[:student][:project_id] = p
      @student.attributes = s[:student]
      @student.save!
      i += 1
    end

    cs = Student.find_by_sql "SELECT MAX( tour ) AS mt FROM `students`WHERE project_id IS NOT NULL OR project_id != 0"
    @last_tour = cs[0].mt

    @nass_students.each do |nas|
      @student = Student.find(nas)
      s = {}
      s[:student] = {}
      s[:student][:tour] = @last_tour.to_i + 1
      @student.attributes = s[:student]
      @student.save!
    end


  end

  def my_projects
    # Need to have different results for staff and students
    if ! session[:user_id]
      flash[:notice] = "You need to be logged in to see your own projects!"
      redirect_to :action => "index"
    else
      @projects = Project.find(:all,
        :conditions => ["created_by = ?", session[:user_id]])
    end
  end

  def by_supervisor
    @projects = Project.find_by_sql "SELECT p.title, p.id, u.last_name FROM `projects` AS p, users AS u WHERE p.created_by = u.id ORDER BY u.last_name ASC"
  end

  def by_discipline
    @disciplines_projects = DisciplinesProjects.find(:all, :order =>'discipline_id')
  end

  def by_centre
    @projects = Project.find(:all)
  end

  protected
  
  def can_edit
    # TODO write and test this method!
    # current user can edit this resource if:
    #   * he/she has the admin role, or
    #   * he/she has the coordinator role, or
    #   * he/she created the resource
    unless true
      flash[:error] = 'You are not authorized to alter this project'
      redirect_to back_or_default('/')
    end
  end
    
  private

  def handle_disciplines_projects
    if params['discipline_ids']
      @project.disciplines.clear
      disciplines = params['discipline_ids'].map { |id| Discipline.find(id) }
      @project.disciplines << disciplines
    end
  end

  def collect_disciplines
    @disciplines = {}
    Discipline.find(:all).collect {|r| @disciplines[r.long_name] = r.id }
  end


end
