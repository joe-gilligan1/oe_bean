def var x   as int.

def var l_output_file as char no-undo.
def var l_userid like usr_mstr.usr_userid.  
def var l_site   like usr_mstr.usr_site.
def var l_uid as char.
def var l_name   like usr_mstr.usr_name. 
def var l_rest   like usr_mstr.usr_restrict.
def var l_long_name as char format 'x(45)'.
 
 

define stream erx.

output to 'xm.txt'.
for each mon_mstr no-lock:
   assign l_uid    = string(mon_mstr.mon__qadi01,'>>>>9') 
          l_long_name = mon_mstr.mon_program.
   find first mnd_det no-lock
        where mnd_exec = mon_mstr.mon_program no-error.
   if available(mnd_det) and mnd_det.mnd_label <> '' then
        l_long_name = mnd_det.mnd_label.

   find first usr_mstr no-lock
        where mon_mstr.mon_userid = usr_mstr.usr_userid
              no-error.
   if available(usr_mstr) then 
    assign l_userid = usr_mstr.usr_userid  
           l_site   = usr_mstr.usr_site  
           l_name   = usr_mstr.usr_name  
           l_rest   = not usr_mstr.usr_active. 
           
   export delimiter '|' 
          mon_mstr.mon_prog_user
          mon_mstr.mon_sid
          mon_mstr.mon_time_start
          mon_mstr.mon_login_time
          mon_mstr.mon_program
          mon_mstr.mon_userid
          mon_mstr.mon_interface
          mon_mstr.mon_product
          l_long_name
          l_site
          l_uid 
          l_name 
          l_rest.
end.
output close.
output stream erx close.
