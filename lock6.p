def var x   as int.
def var xlt as int.
def var ct  as int.
def var l_parent_pid as char no-undo.
def var l_subcommand as char no-undo.
xlt = time.
def var l_input_file  as char no-undo.
def var l_output_file as char no-undo.
def var l_usr   as int no-undo.
def var l_pid   as int no-undo.
def var l_username as char no-undo. 
def var l_workstation as char no-undo.
def var l_db          as char no-undo.
def var l_table_name  as char no-undo.

def temp-table dbxref
   field usr         as int 
   field pid         as int  format '>>>>9' 
   field username    as char format 'x(15)' 
   field workstation as char format 'x(15)' 
   field db          as char  
   field io_id        as int 
   field io_ai_read   as int 
   field io_ai_write  as int
   field io_bi_read   as int
   field io_bi_write  as int
   field io_db_access as int 
   field io_db_read   as int
   field io_db_write  as int 
      index pri as primary unique 
         usr pid username workstation db.
def buffer t_dbxref for dbxref.

define stream erx.


output stream erx to '/tmp/scan_lock.txt' append.

/**** read input file */

l_input_file = 'xd.txt'.

if search(l_input_file) = ? then leave.

input through value('cat ' + l_input_file).
repeat:
  import delimiter '|' 
         l_usr  
         l_pid 
         l_username 
         l_workstation 
         l_db .
  find first dbxref
       where dbxref.usr         = l_usr 
         and dbxref.pid         = l_pid 
         and dbxref.username    = l_username 
         and dbxref.workstation = l_workstation 
         and dbxref.db          = l_db 
             no-error.
  if not available(dbxref) then 
  do:
     create t_dbxref.
     assign t_dbxref.usr         = l_usr 
            t_dbxref.pid         = l_pid 
            t_dbxref.username    = l_username 
            t_dbxref.workstation = l_workstation 
            t_dbxref.db          = l_db.
  end.
end.
input close.

/** collate users against the userio table for this database */

for each dbxref:
  for each _userio where _userio._userio-usr = dbxref.usr:
     assign dbxref.io_id        = _userio._userio-id
            dbxref.io_ai_read   = _userio._userio-airead
            dbxref.io_ai_write  = _userio._userio-aiwrite
            dbxref.io_bi_read   = _userio._userio-biread
            dbxref.io_bi_write  = _userio._userio-biwrite
            dbxref.io_db_access = _userio._userio-dbaccess
            dbxref.io_db_read   = _userio._userio-dbread
            dbxref.io_db_write  = _userio._userio-dbwrite.
  end.
end.  
/*** export file with cross-reference information */
                   
output to value('xdl.txt').
for each _lock no-lock:
   pause 0 before-hide. 
   x = x + 1. 
   if time - xlt >= 2 then leave. 
   if _lock._lock-name = ? then next. 
   xlt = time. 
   find first dbxref no-lock
        where dbxref.usr = _lock._lock-usr no-error. 
        
   find first _file no-lock where  
        _file._file-number = _lock._lock-table no-error.   
   if available(_file) then l_table_name = _file._file-name. 
   
   if available(dbxref) then
   do:
     export delimiter '|' 
            dbxref.usr 
            dbxref.pid 
            dbxref.username 
            dbxref.workstation
            dbxref.db         
            _lock._lock-id        
            _lock._lock-type      
            _lock._lock-flags
            l_table_name
            dbxref.io_db_access
            dbxref.io_db_read
            dbxref.io_db_write
            dbxref.io_bi_read
            dbxref.io_bi_write
            dbxref.io_ai_read
            dbxref.io_ai_write.
   end.
end.
output close.
output stream erx close.
