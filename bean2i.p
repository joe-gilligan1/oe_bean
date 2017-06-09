def var l_database_list as char format 'x(60)' extent 10 
   init ['/u/db/ee2010/qadval/mfgprod' 
        ,'/u/db/ee2010/qadval/hlpprod'
        ,'/u/db/ee2010/qadval/admprod'
        ,'/u/db/ee2010/qadval/cusprod',''] no-undo.

def var l_proddb as char 
   init '/u/db/ee2010/qadval/mfgprod'.

def var l_invoice_locking as char format 'x(250)' no-undo.

assign l_invoice_locking = 
          'ih_hist,idh_hist,lad_det,ar_mstr,so_mstr,sod_det,glt_det' +
          ',Dinvoice,Cinvoice,tx2d_det,nr_mstr,rnd_mstr,gltr_hist'.
     
def var l_choice             as int no-undo.  
def var l_session_count      as int no-undo.
def var l_database_count     as int no-undo.
def var l_database_locks     as int no-undo.
def var l_database_hardlocks as int no-undo.
def var l_database_nicelocks as int no-undo.
def var l_unique_user_count  as int no-undo. 

def temp-table dbxref
  field usr as int
  field pid as int  format '>>>>>9'
  field session_start_date as date 
  field session_start_time as integer
  field username as char format 'x(15)'
  field workstation as char format 'x(15)'
  field dbok as logical extent 10
  field dbdt as integer extent 10
  field db   as char format 'x(90)' extent 10
  field killed as logical
  field hard_locks as int format '>>>>9' init 0 
  field soft_locks as int format '>>>>9' init 0
  field nice_locks as int format '>>>>9' init 0
  field lazytime   as int init 0
  field sessions   as int init 0
    index pri as primary unique 
          usr pid username workstation session_start_time.

def buffer origdx   for dbxref.
def buffer t_dbxref for dbxref.

def temp-table usrlst 
   field username        as char
   field cnt             as int
      index pri as primary unique username.

def temp-table lock_dbxref
   field usr             as int
   field pid             as int
   field username        as char
   field workstation     as char
   field db              as char format 'x(90)' 
   field lock_id         as int
   field lock_type       as char
   field lock_flags      as char
   field lock_table_name as char
   field lock_db_access  as int
   field lock_db_read    as int
   field lock_db_write   as int
   field lock_bi_read    as int
   field lock_bi_write   as int
   field lock_ai_read    as int
   field lock_ai_write   as int
      index pri as primary unique 
            usr pid username workstation db lock_id.
def buffer t_lock_dbxref for lock_dbxref.

define temp-table mon_dbxref
   field username      as char
   field sid           as char 
   field start_time    as int
   field login_time    as int
   field program       as char
   field prog_user     as char
   field interface     as char
   field product       as char
   field long_progname as char format 'x(45)'
   field site          as char
   field uid           as int 
   field long_username as char format 'x(35)'
   field restrict      as logi
   field tagged        as logi
   field pid           as int
   field usr           as int
      index pri as primary unique sid username.
define buffer t_mon_dbxref for mon_dbxref.

define query list_summary for dbxref scrolling.

define browse br1 query list_summary
   display dbxref.username format 'x(12)'   label 'User'
           dbxref.work     format 'x(15)'  label 'Station'
           dbxref.usr      format '>>9'    label 'UID'
           dbxref.pid      format '>>>>>9'  label 'PID'
              with 10 down row 2 title "User List".      

define frame fr_br1 br1 with no-box row 1 down.
def stream p.

procedure show_detail.
   def var l_db_time_differential as int no-undo.
   def var l_nice_username as char format 'x(15)' no-undo.
   def var l_nice_progname as char format 'x(15)' no-undo.
   def var l_nice_lazytime as int  no-undo.
   def var l_nice_group    as logi no-undo.
   def var l_lock_cnt      as int  no-undo.
   def var l_lock_nice     as int  no-undo.
   def var l_lock_hard     as int  no-undo.
   def var l_locks         as logi no-undo.
   def var l_lock_read_tot  as int no-undo format '>>>>>>>>>9-'.
   def var l_lock_write_tot as int no-undo format '>>>>>>>>>9-'.
   def var l_lock_loop     as int  no-undo.
   def var l_nice_lazystr  as char no-undo.
   def var l_sd_cnt        as int  no-undo.
   def var l_sd_dbcnt2     as int  no-undo.
   def var l_sd_lencnt     as int  no-undo.
   def var l_connect_db_check1 as logi no-undo.
   def var l_connect_db_check2 as logi no-undo.
   def var l-short as char format 'x(15)' no-undo.
   def var l_pid_uid_dbconnect_string as char format 'x(7)' no-undo.


   if available(dbxref) then 
   do:

      /*** per iteration logical field updates */
      /*** PID/UID Broker Check 1 */
      assign l_connect_db_check1 = no 
             l_db_time_differential = 0.
             
      do l_sd_cnt = 1 to 10: 
         if dbxref.db[l_sd_cnt] = '' then next. 
         l_db_time_differential = 
            l_db_time_differential + dbxref.dbdt[l_sd_cnt]. 
      end.    
                   
      if l_db_time_differential < 30 
         then l_connect_db_check1 = yes.   
   
      /*** PID/UID Broker Check 2 */ 
      assign l_connect_db_check2 = no
             l_sd_dbcnt2 = 0
             l_pid_uid_dbconnect_string = ''. 
 
      do l_sd_cnt = 1 to 10: 
         if dbxref.db[l_sd_cnt] = '' then next. 
         if dbxref.dbok[l_sd_cnt] = yes then l_sd_dbcnt2 = l_sd_dbcnt2 + 1. 
         l-short = ''. 
         do l_sd_lencnt = 1 to length(dbxref.db[l_sd_cnt]): 
            if l-short = '' and  
                   substr(dbxref.db[l_sd_cnt],
                   length(dbxref.db[l_sd_cnt]) - l_sd_lencnt,1) = '/' 
               then l-short =                    substr(dbxref.db[l_sd_cnt],
                   length(dbxref.db[l_sd_cnt]) - l_sd_lencnt + 1).
         end. 
         l_pid_uid_dbconnect_string = 
               l_pid_uid_dbconnect_string + substring(l-short,1,1).
      end. 
      if l_sd_dbcnt2 = l_database_count then l_connect_db_check2 = yes. 
 
      assign l_nice_username = '' 
             l_nice_progname = '' 
             l_nice_lazytime = 0
             l_nice_lazystr = ''.

      find first mon_dbxref no-lock
           where mon_dbxref.pid = dbxref.pid
             and mon_dbxref.uid = dbxref.usr
                 no-error.
      
      if available(mon_dbxref) then
      do:
         assign l_nice_username = mon_dbxref.long_username
                l_nice_progname = mon_dbxref.long_progname
                l_nice_lazytime = time - mon_dbxref.start_time 
                l_nice_lazystr = string(l_nice_lazytime,'hh:mm:ss') 
                l_nice_group = yes.
      end.
      if l_nice_progname begins 'mfnew' then l_nice_lazytime = -1.
      if l_nice_lazytime = -1 then l_nice_lazystr = 'On Menu'.
      if l_nice_progname = 'mfnewa3.p' then l_nice_progname = 'Main Menu'.
      

      assign l_locks     = no
             l_lock_cnt  = 0
             l_lock_nice = 0
             l_lock_hard = 0
             l_lock_loop = 0.
      
      for each  lock_dbxref no-lock
          where lock_dbxref.usr = dbxref.usr
            and lock_dbxref.pid = dbxref.pid:
         l_lock_cnt = l_lock_cnt + 1.
         if lock_dbxref.lock_flags <> 'S' then 
         do:
            assign l_lock_hard = l_lock_hard + 1
                   l_locks = yes.
            if lookup(lock_dbxref.lock_table,l_invoice_locking) > 0 then 
               assign l_lock_nice = l_lock_nice + 1.
         end.
      end.

      if l_lock_cnt > 0 then 
      do:
         assign l_lock_loop      = 0 
                l_lock_read_tot  = 0
                l_lock_write_tot = 0.
         sub_list:
         for each  lock_dbxref no-lock
             where lock_dbxref.usr = dbxref.usr
               and lock_dbxref.pid = dbxref.pid
                   by lock_flags descend with frame lx:
            assign l_lock_loop = l_lock_loop + 1
                   l_lock_read_tot = lock_dbxref.lock_db_read + 
                                     lock_dbxref.lock_bi_read +
                                     lock_dbxref.lock_ai_read + 
                                     lock_dbxref.lock_db_access
                   l_lock_write_tot = lock_dbxref.lock_db_write + 
                                      lock_dbxref.lock_bi_write +
                                      lock_dbxref.lock_ai_write.
            if l_lock_loop <= 0 then next.                   
            if l_lock_loop > 3 then next.
            display lock_dbxref.lock_id    format '>>>>>9'   label 'ID'
                    lock_dbxref.lock_type  format 'xxx' label 'Type'
                    lock_dbxref.lock_flags format 'x(8)' label 'Flag'
                    lock_dbxref.lock_table_name format 'x(15)' label 'File'
                    with frame lx title "Top Locks for this User"
                          row 15 4 down.
         end.
      end. else 
      do:
         hide frame lx.
      end.      
     
      view frame x1.
      view frame lx.
      display dbxref.killed                     label "Kill?"  skip
              dbxref.usr when available(dbxref) label "  UID"  skip
              dbxref.pid when available(dbxref) label "  PID"  skip
              l_pid_uid_dbconnect_string        label "In DB"  skip
              dbxref.session_start_date         label 'Login'  
              string(dbxref.session_start_time,'hh:mm:ss') 
                                                no-label       skip 
              l_nice_username format 'x(25)'    label ' Name'  skip
              l_nice_progname format 'x(25)'    label ' Prog'  skip
              l_nice_lazystr                    label ' Time'  skip
              l_locks                           label 'Locks' 
              dbxref.nice_locks format '>>>9'  no-label "/"
              dbxref.hard_locks format '>>>>9' no-label "/" 
              dbxref.soft_locks format '>>>>9' no-label skip
              dbxref.sessions                   label '# Lic'  skip
              l_lock_read_tot                   label ' Read'  skip
              l_lock_write_tot                  label 'Write'
                 with frame x1 row 1   title "Detail Info"
                      col 46 side-labels. 
   end.  
end procedure.


procedure retdate.
   define input  parameter in-date as char.
   define input  parameter in-time as char.
   define output parameter l-date as date.
   define output parameter l-time as int.

   def var l-month as char format 'xxx' extent 12  init     
    ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
    no-undo.
   def var l-work as char no-undo.
   def var l-mon  as int  no-undo.
   def var l-day  as int  no-undo.
   def var l-yr   as int  no-undo.
   
   l-work = in-date.
   do l-mon = 1 to 12:
     if index(l-work,l-month[l-mon]) > 0 then
       assign l-day = int(substring(l-work,index(l-work,'+') + 1,
                      index(l-work,'|') - index(l-work,'+') - 1)) 
              l-yr  = int(substring(l-work,index(l-work,'|') + 1,5)) 
              l-date = date(l-mon,l-day,l-yr).
   end.
   assign l-work = in-time
          l-time = int(substr(l-work,1,2)) * 3600 +  
                   int(substr(l-work,4,2)) * 60 +  
                   int(substr(l-work,7,2)).
end procedure.

procedure get_dblist.
   def var l_cnta   as int  no-undo.
   def var l_cntb   as int  no-undo.
   def var l_cmdstr as char no-undo.
   def var l_date   as date no-undo.
   def var l_time   as int  no-undo.
   def var l_initial_result as char format 'x(15)' extent 10.
   do l_cnta = 1 to 10:
      if l_database_list[l_cnta] = '' then next.
      assign l_cmdstr = 'proshut ' + l_database_list[l_cnta] + ' -C list |'
             + "awk '" + chr(123) + " print $1"
             + '" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11'
             + '; ' + chr(125) + "'" + ' | quoter -d " "'.
    
      input stream p through value(l_cmdstr).
      repeat while true:
         import stream p l_initial_result.
         if l_initial_result[1] = 'usr' then next.
         l_date = ?.
         l_time = 0.
         run retdate(input l_initial_result[4] + 
                     "+" + l_initial_result[5] + 
                     "|" + l_initial_result[7], 
                  input l_initial_result[6], 
                  output l_date, 
                  output l_time).

         if length(l_initial_result[1]) > 9 or 
            length(l_initial_result[2]) > 9 then next.
         if index("apw,biw,wdog",l_initial_result[8]) > 0 then next.
      
         find first dbxref where dbxref.usr      = int(l_initial_result[1])
                             and dbxref.pid      = int(l_initial_result[2])
                             and dbxref.username = l_initial_result[8]
                             and dbxref.work     = l_initial_result[9] 
                                 no-error.
  
         if not available(dbxref) then 
         do:
            create t_dbxref.
            assign t_dbxref.usr      = int(l_initial_result[1]) 
                   t_dbxref.pid      = int(l_initial_result[2]) 
                   t_dbxref.username = l_initial_result[8] 
                   t_dbxref.work     = l_initial_result[9]
                   t_dbxref.session_start_date   = l_date 
                   t_dbxref.session_start_time   = l_time 
                   t_dbxref.db[l_cnta]    = l_database_list[l_cnta]
                   t_dbxref.dbok[l_cnta]  = yes
                   t_dbxref.dbdt[l_cnta]  = 0.
            release t_dbxref.
         end. else
         do:
            find first origdx where dbxref.usr      = origdx.usr
                                and dbxref.pid      = origdx.pid
                                and dbxref.username = origdx.username
                                and dbxref.work     = origdx.work no-lock.
            if available(origdx) then 
            do:
               find first t_dbxref 
                    where rowid(t_dbxref) = rowid(dbxref) no-error.
               if available(t_dbxref) then 
                 assign t_dbxref.dbok[l_cnta] = yes
                        t_dbxref.db  [l_cnta] = l_database_list[l_cnta] 
                        t_dbxref.dbdt[l_cnta] = 
                           l_time - origdx.session_start_time.
               release t_dbxref.
            end.
         end.
      end.
      input stream p close.
   end.
   
   for each dbxref 
       break by dbxref.username
             by dbxref.pid: 
      if first-of(dbxref.pid) then 
      do transaction:
         find first usrlst where usrlst.username = dbxref.username  no-error.
         if not available(usrlst) then 
         do:
            create usrlst.
            assign usrlst.username = dbxref.username
                   usrlst.cnt      = 1.
         end. else usrlst.cnt = usrlst.cnt + 1.
      end.    
   end.
  
   for each usrlst:
      do transaction:
         for each  t_dbxref exclusive-lock
             where t_dbxref.username = usrlst.username:
            t_dbxref.sessions = usrlst.cnt.
         end.
      end.
   end.
end procedure.

procedure get_lock_dbxref:

   def var l_cnta      as int  no-undo.
   def var l_cmdstr    as char no-undo.
   def var l_lock_cnt  as int  no-undo.
   def var l_lock_hard as int  no-undo.
   def var l_lock_nice as int  no-undo.
   def var ll_usr      as int no-undo.
   def var ll_pid      as int no-undo.
   def var ll_username    as char no-undo.
   def var ll_workstation as char no-undo.
   def var ll_db       as char no-undo.
   def var ll_id       as int  no-undo.
   def var ll_type     as char no-undo.
   def var ll_flags    as char no-undo.
   def var ll_table    as char no-undo.
   def var ll_db_access as int no-undo.
   def var ll_db_read   as int no-undo.
   def var ll_db_write  as int no-undo.
   def var ll_bi_read   as int no-undo.
   def var ll_bi_write  as int no-undo.
   def var ll_ai_read   as int no-undo.
   def var ll_ai_write  as int no-undo.
   do l_cnta = 1 to 10:
      if l_database_list[l_cnta] = '' then next.
      
      output to value('xd.txt'). 
      for each dbxref where dbxref.db[l_cnta] = l_database_list[l_cnta]
                         by dbxref.username   
                         by dbxref.pid.
         export delimiter '|' 
                dbxref.usr 
                dbxref.pid 
                dbxref.username 
                dbxref.workstation 
                dbxref.db[l_cnta].
      end.
      output close.
      pause 0 before-hide.
      l_cmdstr = '/u/tmp/bean/ee/xref1a.sh ' + l_database_list[l_cnta].
      unix silent value(l_cmdstr). 
      if search('xdl.txt') <> ? then
      do:
         input through value('cat xdl.txt').
         repeat:
            import delimiter '|' 
                   ll_usr
                   ll_pid 
                   ll_username
                   ll_workstation
                   ll_db
                   ll_id
                   ll_type
                   ll_flags
                   ll_table
                   ll_db_access
                   ll_db_read
                   ll_db_write 
                   ll_bi_read
                   ll_bi_write
                   ll_ai_read
                   ll_ai_write. 
         
            find first lock_dbxref   
                 where lock_dbxref.usr         = ll_usr  
                   and lock_dbxref.pid         = ll_pid  
                   and lock_dbxref.username    = ll_username  
                   and lock_dbxref.workstation = ll_workstation  
                   and lock_dbxref.db          = ll_db  
                   and lock_dbxref.lock_id     = ll_id
                       no-error.  
            if not available(lock_dbxref) then  
            do:  
               create t_lock_dbxref.  
               assign t_lock_dbxref.usr         = ll_usr  
                      t_lock_dbxref.pid         = ll_pid  
                      t_lock_dbxref.username    = ll_username   
                      t_lock_dbxref.workstation = ll_workstation  
                      t_lock_dbxref.db          = ll_db
                      t_lock_dbxref.lock_id     = ll_id
                      t_lock_dbxref.lock_type   = ll_type
                      t_lock_dbxref.lock_flags  = ll_flags
                      t_lock_dbxref.lock_table  = ll_table
                      t_lock_dbxref.lock_db_access = ll_db_access 
                      t_lock_dbxref.lock_db_read   = ll_db_read
                      t_lock_dbxref.lock_db_write  = ll_db_write
                      t_lock_dbxref.lock_bi_read   = ll_bi_read
                      t_lock_dbxref.lock_bi_write  = ll_bi_write
                      t_lock_dbxref.lock_ai_read   = ll_ai_read 
                      t_lock_dbxref.lock_ai_write  = ll_ai_write. 
            end.  /** create */
         end.    /** input */
         input close.
      end.     /* do */

      message 'collating ' + l_database_list[l_cnta] + ' lock records'.
   
      if l_database_list[l_cnta] = l_proddb then 
      do:
         pause 0 before-hide.
         message 'collating qad monitor records'.  
         unix silent value('/u/tmp/bean/ee/xref3a.sh ' + 
            l_database_list[l_cnta]). 
      end.
   end.
      
   for each dbxref no-lock:
      assign l_lock_cnt  = 0
             l_lock_hard = 0
             l_lock_nice = 0.
      for each  lock_dbxref no-lock
          where lock_dbxref.usr = dbxref.usr
            and lock_dbxref.pid = dbxref.pid:
         l_lock_cnt = l_lock_cnt + 1.
         if lock_dbxref.lock_flags <> 'S' then 
         do:
            l_lock_hard = l_lock_hard + 1.
            if lookup(lock_dbxref.lock_table,l_invoice_locking) > 0 
               then l_lock_nice = l_lock_nice + 1.
         end.
      end.
      do transaction:
         find t_dbxref where rowid(t_dbxref) = rowid(dbxref) no-error.
         if available(t_dbxref) then
            assign t_dbxref.soft_locks = l_lock_cnt
                   t_dbxref.hard_locks = l_lock_hard
                   t_dbxref.nice_locks = l_lock_nice.
              
         release t_dbxref.
      end.             
   end.
end procedure.

procedure get_mon_dbxref:
   def var l_cnt            as int  no-undo.
   def var l_cmdstr         as char no-undo.
   def var lm_username      as char no-undo.
   def var lm_sid           as char no-undo.
   def var lm_start_time    as int  no-undo.
   def var lm_login_time    as int  no-undo.
   def var lm_program       as char no-undo.
   def var lm_prog_user     as char no-undo.
   def var lm_interface     as char no-undo.
   def var lm_product       as char no-undo.
   def var lm_long_progname as char no-undo.
   def var lm_site          as char no-undo.
   def var lm_uid        as int no-undo.
   def var lm_long_username as char no-undo.
   def var lm_restrict      as logi no-undo.

   if search('xm.txt') <> ? then  
   do: 
      input through value('cat xm.txt'). 
      repeat:
         import delimiter "|"
                lm_username
                lm_sid
                lm_start_time
                lm_login_time
                lm_program
                lm_prog_user
                lm_interface
                lm_product
                lm_long_progname
                lm_site
                lm_uid
                lm_long_username
                lm_restrict
                .
         
         find first mon_dbxref no-lock 
              where mon_dbxref.username = lm_username
                and mon_dbxref.sid      = lm_sid 
                    no-error.
         
         if not available(mon_dbxref) then 
         do:
            create t_mon_dbxref.
            assign t_mon_dbxref.username   = lm_username
                   t_mon_dbxref.sid        = lm_sid
                   t_mon_dbxref.start_time = lm_start_time
                   t_mon_dbxref.login_time = lm_login_time
                   t_mon_dbxref.program    = lm_program
                   t_mon_dbxref.prog_user  = lm_prog_user
                   t_mon_dbxref.interface  = lm_interface
                   t_mon_dbxref.product    = lm_product
                   t_mon_dbxref.long_progname = lm_long_progname
                   t_mon_dbxref.site          = lm_site
                   t_mon_dbxref.uid           = lm_uid
                   t_mon_dbxref.usr           = lm_uid
                   t_mon_dbxref.long_username = lm_long_username
                   t_mon_dbxref.restrict      = lm_restrict.
         end.
      end.
   end.
   input close.

   for each  dbxref no-lock   
       where dbxref.db[1] = l_proddb
             by dbxref.session_start_time :  

      /**** implicit SID order */
    
      find first mon_dbxref no-lock
           where mon_dbxref.username = dbxref.username  
             and mon_dbxref.uid      = dbxref.usr
             and mon_dbxref.tagged   = no
                 no-error.
     
      if available(mon_dbxref) then
      do:
         find first t_mon_dbxref 
              where rowid(mon_dbxref) = rowid(t_mon_dbxref)
                    no-error.
         if available(t_mon_dbxref) then 
         do:
           assign t_mon_dbxref.tagged = yes
                  t_mon_dbxref.pid    = dbxref.pid
                  t_mon_dbxref.usr    = dbxref.usr.
            release t_mon_dbxref.
         end.
      end.
   end.
   
   for each dbxref:
      find first mon_dbxref no-lock
           where dbxref.pid = mon_dbxref.pid 
                 no-error.

      if available(mon_dbxref) then 
      do:
         find first t_dbxref where rowid(t_dbxref) = rowid(dbxref) no-error.
         if available(t_dbxref) then
            assign t_dbxref.lazytime = time - mon_dbxref.start_time.
      end.
   end.
end procedure.


procedure global_counts.
   def var l_cnta               as int no-undo.
   assign l_unique_user_count = 0 
          l_session_count     = 0
          l_database_count    = 0
          l_database_locks    = 0
          l_database_nicelocks = 0
          l_database_hardlocks = 0
          .

   for each dbxref break by dbxref.pid:
      assign l_session_count = l_session_count + 1
             l_unique_user_count = l_unique_user_count + 1
               when  first-of(dbxref.pid). 
   end.

   do l_cnta = 1 to 10:
      assign l_database_count = l_database_count + 1
                when l_database_list[l_cnta] <> "".
   end.

   for each lock_dbxref no-lock:
      assign l_database_locks = l_database_locks + 1
             l_database_hardlocks = l_database_hardlocks + 1 
                when lock_dbxref.lock_flags <> 'S' 
             l_database_nicelocks = l_database_nicelocks + 1 
                when lookup(lock_dbxref.lock_table,l_invoice_locking) > 0
             .
   end.
end procedure.

procedure global_counts_message.   
   def var l_choice_str as char init ''. 
   if l_choice = 1 then l_choice_str = ',logon time'.
   if l_choice = 2 then l_choice_str = ',username'.
   if l_choice = 3 then l_choice_str = ',db lks'.
   if l_choice = 4 then l_choice_str = ',sessions'.
   if l_choice = 5 then l_choice_str = ',time idle'.

   run global_counts.
   hide message.
   message string(l_database_count,'>9') + " db's, " 
           trim(string(l_unique_user_count,'>>9')) + " usr "
           trim(string(l_session_count,'>>9')) + " sess "
           trim(string(l_database_nicelocks,'>>>9')) + " nice"
           trim(string(l_database_locks,'>>>9')) + " soft "
           trim(string(l_database_hardlocks,'>>>9')) + " hard"
           l_choice_str.
end procedure.

procedure kill_user:
   def var l_cnta   as int  no-undo.
   def var l_cmdstr as char no-undo.
   def var l_longname as char format 'x(15)' no-undo.
   def var l_longprog as char format 'x(15)' no-undo.
   find first origdx where rowid(origdx) = rowid(dbxref) no-error.
   def var q as char .
   
   assign q = chr(34).

   if available(origdx) then
   do:
      if origdx.workstation matches "*batch*" then
      do:
         message "cannot kill batch user :" origdx.username.
         output to '/tmp/qad-kill.log' append.
         put q + string(today,'99/99/9999') 
             + ' at ' + string(time,'hh:mm:ss') 
             + ' '    + string(dbxref.usr,'>>>>>>9') 
             + ':'    + string(dbxref.pid,'>>>>>>9')
             ' batch user attempted kill.'  
             + q  format 'x(180)' skip.
         output close.
      end. else
      do:
         output to 'kill.sh'.
         put '. /u/apps/bin/ee.env' skip.
         output close.
         assign l_longprog = '--- NA ---'
                l_longname = dbxref.username.
         do l_cnta = 1 to 10:
            if l_database_list[l_cnta] = '' then next.
           
            output to 'kill.sh' append. 
            for each t_dbxref no-lock
                where t_dbxref.db[l_cnta] = l_database_list[l_cnta]
                  and t_dbxref.pid        = origdx.pid 
                      by t_dbxref.username    
                      by t_dbxref.pid.

               find first mon_dbxref where mon_dbxref.pid = dbxref.pid
                                       and mon_dbxref.usr = dbxref.usr
                                           no-error.
            
               if available(mon_dbxref) and mon_dbxref.long_username <> '' then 
                  assign l_longname = mon_dbxref.long_username  
                         l_longprog = mon_dbxref.long_progname.
                                         
               assign l_cmdstr = 'proshut ' + l_database_list[l_cnta] 
                      + ' -C disconnect' + string(t_dbxref.usr,'>>>>>9').
               put 'echo ' + q + string(today,'99/99/9999') 
                   + ' at ' + string(time,'hh:mm:ss') 
                   + ' '    + string(dbxref.usr,'>>>>>>9') 
                   + ':'    + string(dbxref.pid,'>>>>>>9')
                   + ':'    + l_longname + ' running ' 
                   + l_longprog + ' attempted kill.' 
                   + q      + ' >> /tmp/qad-kill.log' 
                    format 'x(180)' skip.
               put l_cmdstr format 'x(180)' skip.
            end.
            output close.
            do transaction:
               for each t_dbxref exclusive-lock
                   where t_dbxref.pid    = origdx.pid: 
                  assign t_dbxref.killed = yes.
               end.
            end.                
         end.
         message "terminating user " origdx.pid.
         unix silent value('chmod 700 ./kill.sh').
         unix silent value('./execute.sh').      
      end.
   end.
end.

procedure manage_user.
   def var l_ans     as logi init no no-undo.
   def var l_refresh as logi init no no-undo.
   message "Do you want to kill this connection?" update l_ans.
   if l_ans = yes then 
   do:
      run kill_user.
   end.
end.

procedure browse_by_time.

   on value-changed of br1 in frame fr_br1 run show_detail.  

   on entry of br1 run show_detail.

   on default-action of br1
   do:
      run manage_user.
      run show_detail.
   end.

   open query list_summary
        for each  dbxref no-lock   
                  by dbxref.session_start_time
                  by dbxref.pid.
   enable all with frame fr_br1.
   wait-for window-close of current-window.
   if keyfunction(lastkey) = "END-ERROR" then quit.
end. 

procedure browse_by_username.
   
   on value-changed of br1 in frame fr_br1 run show_detail.  

   on entry of br1 run show_detail.
   
   on default-action of br1
   do:
      run manage_user.
      run show_detail.
   end.

   open query list_summary
       for each  dbxref no-lock  
                 by dbxref.username  
                 by dbxref.pid.
   enable all with frame fr_br1.
   wait-for window-close of current-window.
   if keyfunction(lastkey) = "END-ERROR" then quit.
end. 

procedure browse_by_locks.

   on value-changed of br1 in frame fr_br1 run show_detail.  

   on entry of br1 run show_detail.

   on default-action of br1
   do:
      run manage_user.
      run show_detail.
   end.

   open query list_summary
       for each  dbxref no-lock  
                 by dbxref.nice_locks desc
                 by dbxref.hard_locks desc  
                 by dbxref.soft_locks desc.
   enable all with frame fr_br1.
   wait-for window-close of current-window.
   if keyfunction(lastkey) = "END-ERROR" then quit.
end. 

procedure browse_by_idle.
   on value-changed of br1 in frame fr_br1 run show_detail.  

   on entry of br1 run show_detail.

   on default-action of br1
   do:
      run manage_user.
      run show_detail.
   end.

   open query list_summary
       for each  dbxref no-lock  
                 by dbxref.lazytime desc
                 by dbxref.pid.  
   enable all with frame fr_br1.
   wait-for window-close of current-window.
   if keyfunction(lastkey) = "END-ERROR" then quit.
end. 

procedure browse_by_session.
   on value-changed of br1 in frame fr_br1 run show_detail.  

   on entry of br1 run show_detail.

   on default-action of br1
   do:
      run manage_user.
      run show_detail.
   end.

   open query list_summary
       for each  dbxref no-lock  
                 by dbxref.workstation desc
                 by dbxref.username desc
                 by dbxref.session_start_time.  
   enable all with frame fr_br1.
   wait-for window-close of current-window.
   if keyfunction(lastkey) = "END-ERROR" then quit.
end. 




/****************** MAIN ************/

   on end-error anywhere
   do:
      quit.
   end.
   
   if keyfunction(lastkey) <> "END-ERROR" then 
   do:
     inpx:
     do while l_choice < 1 or l_choice > 5:
        l_choice = 1.
        message 
          "Sort by login time(1), userid(2) or locks(3), logins(4), idle(5)" 
               update l_choice.
      end.
   end.

   run get_dblist.
   run get_lock_dbxref.
   run get_mon_dbxref.
   run global_counts_message.

/*******************/

   if l_choice = 1 then run browse_by_time.
   if l_choice = 2 then run browse_by_username.
   if l_choice = 3 then run browse_by_locks.
   if l_choice = 4 then run browse_by_session.
   if l_choice = 5 then run browse_by_idle.
