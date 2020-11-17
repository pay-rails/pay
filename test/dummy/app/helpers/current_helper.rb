module CurrentHelper
  def current_user
    @current_user ||= User.first || User.create!(email: "test@user.com", first_name: "Test", last_name: "User")
  end

  def current_team
    @current_user ||= Team.first || Team.create!(name: "Test Team", email: "test@team.com", owner: current_user)
  end
end
