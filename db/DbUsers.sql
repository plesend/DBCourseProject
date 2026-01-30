--роли
create role admin_role;
create role manager_role;
create role guest_role;

--юзеры
create user admin_user identified by Kate2006
  DEFAULT TABLESPACE music_ts
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON music_ts;
  
CREATE USER manager_user IDENTIFIED BY Kate2006
  DEFAULT TABLESPACE music_ts
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON music_ts;
  
CREATE USER guest_user IDENTIFIED BY Kate2006
  DEFAULT TABLESPACE music_ts
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON music_ts;
 
--гранты 
GRANT admin_role TO admin_user;
GRANT manager_role TO manager_user;
GRANT guest_role TO guest_user;

--для админа
GRANT DBA TO admin_user;
GRANT EXECUTE ON DBMS_CRYPTO TO admin_user;

--для манагера
GRANT CREATE SESSION TO manager_role;
GRANT CREATE VIEW TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Musicians TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Albums    TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Music     TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Awards    TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Nominants TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Winners   TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Votes     TO manager_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_user.Winners   TO manager_role;
GRANT SELECT ON admin_user.users TO manager_role;
GRANT EXECUTE ON admin_user.pkg_manager TO manager_user;
GRANT CREATE SYNONYM TO manager_role;

--для геста
GRANT CREATE SESSION TO guest_role;
GRANT SELECT ON admin_user.Musicians TO guest_role;
GRANT SELECT ON admin_user.Albums    TO guest_role;
GRANT SELECT ON admin_user.Music     TO guest_role;
GRANT SELECT ON admin_user.Awards    TO guest_role;
GRANT SELECT ON admin_user.Votes     TO guest_role;
GRANT SELECT ON admin_user.Winners   TO guest_role;
GRANT EXECUTE ON admin_user.pkg_guest TO guest_role;
GRANT INSERT ON admin_user.Users TO guest_role;
GRANT INSERT ON admin_user.Votes TO guest_role;
GRANT CREATE SYNONYM TO guest_role;
GRANT EXECUTE ON admin_user.pkg_guest TO guest_role;
GRANT EXECUTE ON DBMS_CRYPTO TO guest_user;





