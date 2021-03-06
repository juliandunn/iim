#
# Cookbook Name:: IBMInstallationManager
# Provider:: IBMInstallationManager
#
# (C) Copyright IBM Corporation 2013.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'tempfile'

action :install do

im_base_dir = "#{node[:im][:base_dir]}"
imdir = "#{im_base_dir}/IBM/InstallationManager"
im_user = node[:im][:user]
im_group = node[:im][:group]

maybe_master_password_file = new_resource.master_password_file
maybe_secure_storage_file = new_resource.secure_storage_file
maybe_response_file = new_resource.response_file
maybe_response_hash = new_resource.response_hash #( a recpipe providing the response file as a ruby object)

credentials_bash_snippet = "" #this goes here for later

  #First check for a secure_storage file. 

   if ((not maybe_secure_storage_file.nil?) and ::File.file?(maybe_secure_storage_file))#TODO, better error handling for a non-nil invalid file
      credentials_bash_snippet = "-secureStorageFile #{maybe_secure_storage_file}"
      if ((not maybe_master_password_file.nil?) and ::File.file?(maybe_master_password_file))
        credentials_bash_snippet = "-secureStorageFile #{maybe_secure_storage_file} -masterPasswordFile #{maybe_master_password_file}" #TODO, add a warning if there's a master password file but no secure storage file?
      end
   end

   #Next check if we have a response file or a response hash. 
   if ::File.file?(maybe_response_file)
	response_file = maybe_response_file 	
   elsif not maybe_response_hash.nil? #if we have both a file and a config, defualt to the file. 
	new_contents = []
	generate_xml(new_resource.response_hash, new_contents)
	response_file = Tempfile.new('install_response_file.xml')
	response_file.write(new_contents)
   else
	z = 1 #todo, throw an error. No response file found. 
   end

   #TODO if the application is alrady installed, do nothing; possibly include a peramiater that lets recipeies state if they want to update. 
   bash 'install' do #TODO include the applicaiton name after install
    user node[:im][:user]
    group node[:im][:group]
    cwd "#{imdir}/eclipse/tools"
    code <<-EOH
        ./imcl -showProgress -acceptLicense input #{::File.path(response_file)} -log /tmp/install_log.xml #{credentials_bash_snippet}
    EOH
   end
end



def generate_xml(indent = "", name = "agent-input acceptLicense=\"true\"", map, output)
  
  attributes = {}
  elements = {}

  map.each_pair do |key, value|
    if value.is_a?(Hash)
      elements[key] = value
    elsif value.is_a?(Array)
      elements[key] = value
    else
      attributes[key] = value
    end
  end

  attributes.each_pair do |key, value|
    line << " #{key}=\"#{evaluate_value(value)}\""
  end

  if !elements.empty?
    line << ">"
    output <<  "#{indent}#{line}"
    
    next_indent = "  #{indent}"
    elements.each_pair do |key, value|
      if value.is_a?(Hash)
        generate_xml(next_indent, key, value, output)
      elsif value.is_a?(Array)
        if value.empty?
           output << "#{next_indent}<#{key}/>"
        elsif value.first.is_a?(Hash)
          value.each do |item|
            generate_xml(next_indent, key, item, output)
          end
        else 
          value.each do |item|
            output << "#{next_indent}<#{key}>#{evaluate_value(item)}</#{key}>"
          end
        end
      end
    end

    output << "#{indent}</#{name}>"
  else
    line << "/>"
    output << "#{indent}#{line}"
  end

end
