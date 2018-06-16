% testFlywheel
api_key = 'flywheel.sas.upenn.edu:MN4WtaSTcBUtI8Zlom';
fw = flywheel.Flywheel(api_key);
all_projects = fw.getAllProjects;
project_label = 'tome';
project = all_projects{contains(cellfun(@(p) {p.label}, all_projects), project_label)};
project_sessions = fw.getProjectSessions(project.id);

session_acquisitions = fw.getSessionAcquisitions(project_sessions{1}.id);

 file_ref = struct('id', session_acquisitions{1}.id, 'type', 'acquisition', 'name', session_acquisitions{1}.files{1}.name);
 analysis = struct('label', 'Test', 'inputs', {{file_ref}});
 analysisId = fw.addProjectAnalysis(project.id, analysis);
 %fw.uploadOutputToAnalysis(analysisId, './T1w.pdf');
