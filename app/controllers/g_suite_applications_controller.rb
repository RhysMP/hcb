class GSuiteApplicationsController < ApplicationController
  before_action :set_g_suite_application, only: [:show, :edit, :update, :destroy]

  # GET /g_suite_applications
  def index
    @g_suite_applications = GSuiteApplication.all
    authorize @g_suite_applications
  end

  # GET /g_suite_applications/1
  def show
    authorize @g_suite_application
  end

  # GET /g_suite_applications/new
  def new
    @g_suite_application = GSuiteApplication.new
  end

  # GET /g_suite_applications/1/edit
  def edit
  end

  # POST /g_suite_applications
  def create
    @g_suite_application = GSuiteApplication.new(g_suite_application_params)

    authorize @g_suite_application

    if @g_suite_application.save
      redirect_to @g_suite_application, notice: 'G suite application was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /g_suite_applications/1
  def update
    authorize @g_suite_application

    if @g_suite_application.update(g_suite_application_params)
      redirect_to @g_suite_application, notice: 'G suite application was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /g_suite_applications/1
  def destroy
    @g_suite_application.canceled_at = Time.now

    authorize @g_suite_application

    redirect_to g_suite_applications_url, notice: 'G suite application was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_g_suite_application
      @g_suite_application = GSuiteApplication.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def g_suite_application_params
      params.require(:g_suite_application).permit(:user_id, :event_id, :user_id, :domain, :rejected_at, :accepted_at, :canceled_at)
    end
end
