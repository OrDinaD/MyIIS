require 'xcodeproj'
project_path = 'MyIIS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
group = project.main_group.find_subpath(File.join('MyIIS', 'Resources'), true)
file_ref = group.new_file('MyIIS/Resources/DepartmentsMockData.swift')
target = project.targets.first
target.add_file_references([file_ref])
project.save
