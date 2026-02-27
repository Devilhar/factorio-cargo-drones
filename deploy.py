import os
import json
import sys
import shutil

def deploy(temp_dir, deploy_to_mod_dir, echo_file):
    with open('cargo-drone/info.json', 'r') as file:
        info_data = json.load(file)

    version = info_data['version']

    output_dir = temp_dir

    if deploy_to_mod_dir:
        output_dir = os.getenv('APPDATA') + "/Factorio/mods/"

    output_temp_path = temp_dir + 'cargo-drone_' + version
    output_filename = output_dir + 'cargo-drone_' + version
    
    if not echo_file:
        print('Copying files to ' + output_temp_path)

    shutil.copytree(src='cargo-drone', dst=output_temp_path, dirs_exist_ok=True)

    if not echo_file:
        print('Creating zip at ' + output_filename + '.zip')

    shutil.make_archive(output_filename, 'zip', temp_dir, 'cargo-drone_' + version)

    if echo_file:
        print(output_filename + '.zip')

deploy(sys.argv[1], "--deploy_to_mod_dir" in sys.argv, "--echo_file" in sys.argv)
