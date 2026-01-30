BEGIN
  FOR i IN 1..100000 LOOP
    INSERT INTO Users (username, gmail, password_hash, role)
    VALUES (
      'user_' || i,
      'user_' || i || '@gmail.com',
      pkg_admin.hash_password('password_' || i),
      CASE WHEN MOD(i, 100) = 0 THEN 'manager_user' ELSE 'guest_user' END);

    IF MOD(i, 1000) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;
  COMMIT;
END;
/


ALTER SESSION SET STATISTICS_LEVEL = ALL;


SET AUTOTRACE ON
SELECT /*+ gather_plan_statistics */ username, role 
FROM Users 
WHERE role = 'manager_user';



select * from Awards;

--жисон

CREATE OR REPLACE DIRECTORY JSON_DIR AS '/opt/oracle/json';
GRANT READ, WRITE ON DIRECTORY JSON_DIR TO admin_user;

SELECT directory_name, directory_path
FROM all_directories
WHERE directory_name = 'JSON_DIR';

BEGIN
  pkg_admin.export_users_to_file('users.json');
END;
/

delete fr

BEGIN
  pkg_admin.import_users_from_file('users.json');
END;
/

DELETE FROM Users;
COMMIT;

select * from users;

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Users;
    DBMS_OUTPUT.PUT_LINE('Количество строк в таблице Users: ' || v_count);
END;
/
--тест админа
BEGIN
  pkg_admin.add_admin(
    p_username => 'superadmin',
    p_gmail    => 'superadmin@gmail.com',
    p_password => 'MySecret123'
  );
END;
/

BEGIN
  pkg_admin.add_admin(
    p_username => 'superadmin',
    p_gmail    => 'superadmin@gmail.com',
    p_password => 'MySecret123'
  );
END;
/

BEGIN
  pkg_admin.update_manager(
    p_user_id  => 2,
    p_username => 'manager_updated',
    p_gmail    => 'manager_updated@gmail.com',
    p_password => 'NewPass123'
  );
END;
/

BEGIN
  pkg_admin.update_manager(
    p_user_id  => 2,
    p_username => 'manager_updated',
    p_gmail    => 'manager_updated@gmail.com',
    p_password => NULL
  );
END;
/

BEGIN
  pkg_admin.delete_manager(p_user_id => 2);
END;
/

DECLARE
  c SYS_REFCURSOR;
  v_id NUMBER;
  v_username VARCHAR2(50);
  v_gmail VARCHAR2(100);
  v_hash VARCHAR2(200);
BEGIN
  pkg_admin.get_all_managers(p_cursor => c);
  LOOP
    FETCH c INTO v_id, v_username, v_gmail, v_hash;
    EXIT WHEN c%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(v_id || ' | ' || v_username || ' | ' || v_gmail);
  END LOOP;
  CLOSE c;
END;
/

BEGIN
  pkg_admin.export_users_to_file(p_filename => 'users_export.json');
END;
/

BEGIN
  pkg_admin.import_users_from_file(p_filename => 'users_export.json');
END;
/


---------------------------
--тест менеджера
BEGIN
  pkg_manager.add_musician(
    p_name => 'New Artist',
    p_info => 'Some info about artist'
  );
END;
/

BEGIN
  pkg_manager.update_musician(
    p_id     => 1,
    p_name   => 'Updated Artist',
    p_info   => 'Updated info',
    p_status => 'participating'
  );
END;
/

BEGIN
  pkg_manager.delete_musician(p_musician_id => 1);
END;
/


BEGIN
  pkg_manager.add_album(
    p_musician_id => 1,
    p_title       => 'New Album',
    p_release_date=> TO_DATE('2025-12-17','YYYY-MM-DD'),
    p_link        => NULL,
    p_pic_link    => NULL
  );
END;
/

BEGIN
  pkg_manager.add_track(
    p_album_id => 1,
    p_title    => 'New Track'
  );
END;
/

BEGIN
  pkg_manager.add_nominant(
    p_award_id => 2,
    p_album_id => 1
  );
END;
/

BEGIN
  pkg_manager.delete_vote(p_vote_id => 5);
END;
/

DECLARE
  c SYS_REFCURSOR;
  v_id NUMBER;
  v_name VARCHAR2(100);
  v_info VARCHAR2(4000);
  v_status VARCHAR2(20);
BEGIN
  pkg_manager.get_musicians(p_cursor => c);
  LOOP
    FETCH c INTO v_id, v_name, v_info, v_status;
    EXIT WHEN c%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(v_id || ' | ' || v_name || ' | ' || v_status);
  END LOOP;
  CLOSE c;
END;
/


DECLARE
  c SYS_REFCURSOR;
  v_id NUMBER;
  v_name VARCHAR2(100);
  v_info VARCHAR2(4000);
  v_status VARCHAR2(20);
BEGIN
  pkg_manager.get_musicians(p_cursor => c);
  LOOP
    FETCH c INTO v_id, v_name, v_info, v_status;
    EXIT WHEN c%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(v_id || ' | ' || v_name || ' | ' || v_status);
  END LOOP;
  CLOSE c;
END;
/

BEGIN pkg_manager.calculate_winners; END;


SET SERVEROUTPUT ON
DECLARE
    v_hash VARCHAR2(256);
    v_uid  NUMBER;
    v_role VARCHAR2(20);
BEGIN
    v_hash := pkg_guest.hash_password('pass123');
    pkg_guest.register_user('guest1','guest1@gmail.com',v_hash);
    pkg_guest.login_user('guest1',v_hash,v_uid,v_role);
    DBMS_OUTPUT.PUT_LINE('user_id='||v_uid||', role='||v_role);
END;
/


BEGIN
    pkg_guest.vote_for_album(
        p_user_id => 1,
        p_award_id => 1,
        p_album_id => 2,
        p_comment_text => 'Cool album'
    );
END;
/

DECLARE
    c SYS_REFCURSOR;
    id NUMBER; n VARCHAR2(150); d VARCHAR2(500);
BEGIN
    pkg_guest.get_awards(c);
    LOOP
        FETCH c INTO id,n,d; EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(id||' | '||n);
    END LOOP;
    CLOSE c;
END;
/

DECLARE
    c SYS_REFCURSOR;
    a_id NUMBER; m_id NUMBER; m_name VARCHAR2(100);
    t VARCHAR2(150); d VARCHAR2(10); l VARCHAR2(200); p VARCHAR2(100);
BEGIN
    pkg_guest.get_albums_by_award(1,c);
    LOOP
        FETCH c INTO a_id,m_id,m_name,t,d,l,p; EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(a_id||' | '||t||' | '||m_name);
    END LOOP;
    CLOSE c;
END;
/


DECLARE
    c SYS_REFCURSOR;
    u VARCHAR2(50); t VARCHAR2(4000);
BEGIN
    pkg_guest.get_comments_by_album(2,c);
    LOOP
        FETCH c INTO u,t; EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(u||': '||t);
    END LOOP;
    CLOSE c;
END;
/

DECLARE
    c SYS_REFCURSOR;
    a NUMBER; m NUMBER; n VARCHAR2(100); i VARCHAR2(500);
    t VARCHAR2(150); d VARCHAR2(10); l VARCHAR2(200); p VARCHAR2(100);
BEGIN
    pkg_guest.get_album_description(2,c);
    FETCH c INTO a,m,n,i,t,d,l,p;
    DBMS_OUTPUT.PUT_LINE(t||' - '||n);
    CLOSE c;
END;
/


DECLARE
    c SYS_REFCURSOR;
    id NUMBER; t VARCHAR2(150);
BEGIN
    pkg_guest.get_tracks_by_album(2,c);
    LOOP
        FETCH c INTO id,t; EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(id||' | '||t);
    END LOOP;
    CLOSE c;
END;
/


DECLARE
    c SYS_REFCURSOR;
    aw NUMBER; awn VARCHAR2(150);
    al NUMBER; alt VARCHAR2(150);
    m NUMBER; mn VARCHAR2(100); pic VARCHAR2(100);
BEGIN
    pkg_guest.get_winners(c);
    LOOP
        FETCH c INTO aw,awn,al,alt,m,mn,pic; EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(awn||' -> '||alt||' ('||mn||')');
    END LOOP;
    CLOSE c;
END;
/

BEGIN
  pkg_guest.vote_for_album(
    p_user_id      => 1,
    p_award_id     => 1,
    p_album_id     => 5,
    p_comment_text => 'ыьуььуь'
  );
END;
/

