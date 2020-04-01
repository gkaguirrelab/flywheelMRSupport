#os.system('pip install pandas')
import flywheel, pandas

def submitFmriprep(csvFile):
    
    # Str to Boolean converter func
    def str2bool(v):
       return str(v).lower() in ("yes", "true", "t", "1")
    
    spreadsheet = pandas.read_csv(csvFile, header=None)
    
    # Get the project label
    projectLabel = spreadsheet.loc[0,1]
    
    # Get the gear name
    gearName = spreadsheet.loc[0,4]
    
    # Get the config keys and vals in a list and combine them in a dict
    configKeys_list = spreadsheet.loc[0,8].split('{')[1].split('}')[0].replace('\'','').split(',')
    configVals_list = spreadsheet.loc[0,10].split('{')[1].split('}')[0].split(',')
    defaultVals = dict(zip(configKeys_list,configVals_list))
    # Convert true and false strings to boolean
    for confs in defaultVals.keys():
        if defaultVals[confs] == 'true' or defaultVals[confs] == 'false' or defaultVals[confs] =='True' or defaultVals[confs] == 'False':
            defaultVals[confs] = str2bool(defaultVals[confs])
    
    # Get the list of inputs 
    inputs = []
    for i in spreadsheet.loc[1,:][spreadsheet.loc[1,:].notnull()][1:]:
        inputs.append(i)
    input_length = len(inputs)
    
    # Initialize flywheel object 
    fw = flywheel.Client()     
    
    # Load the gear 
    gear_loaded = fw.lookup(f'gears/{gearName}')
    
    # Load the project
    project = fw.lookup(f'gkaguirrelab/{projectLabel}')
    
    # Loop through the subjects/sessions from csv
    starting_index = 7
    analysis_ids = []
    fails = []
    for subjsess in spreadsheet.loc[starting_index:,0]:
        # Load the session
        print (subjsess)
        session = fw.lookup(f'gkaguirrelab/mtSinaiFlicker/{subjsess}')
        project_inputs = {}
        project_configs = {}
        for i in range(input_length):
            real_index = i + 1
            if spreadsheet.loc[4, real_index] == 'project':
                if spreadsheet.loc[1, real_index] in defaultVals.keys():
                    project_inputs[spreadsheet.loc[1, real_index]] = defaultVals[spreadsheet.loc[1, real_index]]
                else:
                    project_inputs[spreadsheet.loc[1, real_index]] = project.get_file(spreadsheet.loc[starting_index, real_index])
                if project_inputs[spreadsheet.loc[1, real_index]] == 'false' or project_inputs[spreadsheet.loc[1, real_index]] == 'true' or project_inputs[spreadsheet.loc[1, real_index]] == 'True' or project_inputs[spreadsheet.loc[1, real_index]] == 'False':
                    project_inputs[spreadsheet.loc[1, real_index]] = str2bool(project_inputs[spreadsheet.loc[1, real_index]])
            elif spreadsheet.loc[4, real_index] == 'config':
                if spreadsheet.loc[1, real_index] in defaultVals.keys():
                     project_configs[spreadsheet.loc[1, real_index]] = defaultVals[spreadsheet.loc[1, real_index]]
                else:
                    project_configs[spreadsheet.loc[1, real_index]] = spreadsheet.loc[starting_index, real_index] 
                if project_configs[spreadsheet.loc[1, real_index]] == 'false' or project_configs[spreadsheet.loc[1, real_index]] == 'true' or project_configs[spreadsheet.loc[1, real_index]] == 'True' or project_configs[spreadsheet.loc[1, real_index]] == 'False':
                    project_configs[spreadsheet.loc[1, real_index]] = str2bool(project_configs[spreadsheet.loc[1, real_index]])        
            else:
                analysis_label = spreadsheet.loc[starting_index, real_index]
        try:
            _id = gear_loaded.run(analysis_label=analysis_label,
                              config=project_configs, inputs=project_inputs, destination=session)
            analysis_ids.append(_id)
        except Exception as e:
            print(e)
            fails.append(session) 
        


