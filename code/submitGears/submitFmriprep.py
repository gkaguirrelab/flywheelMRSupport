import os
os.system('pip install pandas flywheel-sdk')
import flywheel, pandas

def submitFmriprep(csvFile, overwrite_existing ='never'):

    # Str to Boolean converter func
    def str2bool(v):
       return str(v).lower() in ("yes", "true", "t", "1")
    
    spreadsheet = pandas.read_csv(csvFile, header=None)
    
    # Get the project label
    projectLabel = spreadsheet.loc[0,1]
    
    # Get the gear name
    gearName = spreadsheet.loc[0,4]
    
    # Get the default config keys and vals in a list and combine them in a dict
    configKeys_list = spreadsheet.loc[0,8].split('{')[1].split('}')[0].replace('\'','').split(',')
    configVals_list = spreadsheet.loc[0,10].split('{')[1].split('}')[0].split(',')
    defaultVals = dict(zip(configKeys_list,configVals_list))
    for confs in defaultVals.keys(): # Convert true and false strings to boolean
        if defaultVals[confs] == 'true' or defaultVals[confs] == 'false' or defaultVals[confs] =='True' or defaultVals[confs] == 'False':
            defaultVals[confs] = str2bool(defaultVals[confs])
    
    # Get the list of inputs 
    inputs = []
    for i in spreadsheet.loc[1,:][spreadsheet.loc[1,:].notnull()][1:]:
        inputs.append(i)
    submissionTagIndex = inputs.index('analysisSubmissionTag') # Get tag index
    input_length = len(inputs) # Get input length
    
    # Initialize flywheel object 
    fw = flywheel.Client()     
    
    # Load the gear 
    gear_loaded = fw.lookup(f'gears/{gearName}')
    
    # Load the project
    project = fw.lookup(f'gkaguirrelab/{projectLabel}')
    
    # Loop through the subjects/sessions from csv
    starting_index = 6 # Iterate this to get the line where subject names start
    analysis_ids = []
    fails = []
    for subjsess in spreadsheet.loc[7:,0]:
        starting_index += 1
        # Load the session
        session = fw.lookup(f'gkaguirrelab/mtSinaiFlicker/{subjsess}')
        project_inputs = {}
        project_configs = {}
        for input_index in range(1, input_length+1):
            if spreadsheet.loc[4, input_index] == 'project':
                if spreadsheet.loc[1, input_index] in defaultVals.keys(): # If in default
                    project_inputs[spreadsheet.loc[1, input_index]] = defaultVals[spreadsheet.loc[1, input_index]]
                else:
                    project_inputs[spreadsheet.loc[1, input_index]] = project.get_file(spreadsheet.loc[starting_index, input_index])
                if project_inputs[spreadsheet.loc[1, input_index]] == 'false' or project_inputs[spreadsheet.loc[1, input_index]] == 'true' or project_inputs[spreadsheet.loc[1, input_index]] == 'True' or project_inputs[spreadsheet.loc[1, input_index]] == 'False':
                    project_inputs[spreadsheet.loc[1, input_index]] = str2bool(project_inputs[spreadsheet.loc[1, input_index]])
            elif spreadsheet.loc[4, input_index] == 'config':
                if spreadsheet.loc[1, input_index] in defaultVals.keys():
                     project_configs[spreadsheet.loc[1, input_index]] = defaultVals[spreadsheet.loc[1, input_index]]
                else:
                    project_configs[spreadsheet.loc[1, input_index]] = spreadsheet.loc[starting_index, input_index] 
                if project_configs[spreadsheet.loc[1, input_index]] == 'false' or project_configs[spreadsheet.loc[1, input_index]] == 'true' or project_configs[spreadsheet.loc[1, input_index]] == 'True' or project_configs[spreadsheet.loc[1, input_index]] == 'False':
                    project_configs[spreadsheet.loc[1, input_index]] = str2bool(project_configs[spreadsheet.loc[1, input_index]])        
            
            # Get the analysis label
            analysis_label = spreadsheet.loc[starting_index, submissionTagIndex+1]
            
        # # Check if the gear was run on this session before
        how_many_instances = len(session.analyses)
        gear_was_run_before = []
        for i in range(how_many_instances):
            if session.analyses[i]['label'] == analysis_label:
                gear_was_run_before.append(1)
            else:
                gear_was_run_before.append(0)           
                
        if 1 not in gear_was_run_before:   
            print (f'Running {gearName} on {subjsess}')        
            try:
                _id = gear_loaded.run(analysis_label=analysis_label,
                                      config=project_configs, inputs=project_inputs, destination=session)
                analysis_ids.append(_id)
            except Exception as e:
                print(e)
                fails.append(session)
        else:
            print('An instance of the gear was run before on this same data. Delete the failed/stopped analysis instances and try again')
 
        # if overwrite_existing == 'failed':
        # fw.delete_acquisition_analysis    
        #     if overwrite_existing == 'never':
        #         try:
        #             _id = gear_loaded.run(analysis_label=analysis_label,
        #                               config=project_configs, inputs=project_inputs, destination=session)
        #             analysis_ids.append(_id)
        #         except Exception as e:
        #             print(e)
        #             fails.append(session)
        #     if overwrite_existing == 'failed'       
                    
        #           if 0 in gear_was_run_before:                   
        #         else:
        #             print('This gear was run on this subject before. Either delete the previous instance or use the "failed: or "all" key for the overwrite_existing flag')
        
        
