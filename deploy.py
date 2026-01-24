import os
import json
import sys
import shutil

def deploy(temp_dir, deploy_to_mod_dir):
    with open('cargo-drone/info.json', 'r') as file:
        info_data = json.load(file)

    version = info_data['version']

    output_dir = temp_dir

    if deploy_to_mod_dir:
        output_dir = os.getenv('APPDATA') + "/Factorio/mods/"

    output_temp_path = temp_dir + 'cargo-drone_' + version
    output_filename = output_dir + 'cargo-drone_' + version
    
    print('Copying files to ' + output_temp_path)

    shutil.copytree(src='cargo-drone', dst=output_temp_path, dirs_exist_ok=True)

    print('Creating zip at ' + output_filename + '.zip')

    shutil.make_archive(output_filename, 'zip', temp_dir, 'cargo-drone_' + version)

deploy(sys.argv[1], "--deploy_to_mod_dir" in sys.argv)
