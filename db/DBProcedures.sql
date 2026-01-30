
--интерфейс для админа
CREATE OR REPLACE PACKAGE pkg_admin AS
 FUNCTION hash_password(p_password VARCHAR2) RETURN VARCHAR2;
 FUNCTION validate_email(p_email VARCHAR2) RETURN NUMBER;

 PROCEDURE add_admin(p_username VARCHAR2,p_gmail VARCHAR2,p_password VARCHAR2);
 PROCEDURE add_manager(p_username VARCHAR2,p_gmail VARCHAR2,p_password VARCHAR2);
 PROCEDURE update_manager(p_user_id NUMBER,p_username VARCHAR2,p_gmail VARCHAR2,p_password VARCHAR2);
 PROCEDURE delete_manager(p_user_id NUMBER);
 PROCEDURE get_all_managers(p_cursor OUT SYS_REFCURSOR);

 PROCEDURE export_users_to_file(p_filename VARCHAR2 DEFAULT 'users_export.json');
 PROCEDURE import_users_from_file(p_filename VARCHAR2);
END pkg_admin;
/

CREATE OR REPLACE PACKAGE BODY pkg_admin AS

FUNCTION hash_password(p_password VARCHAR2) RETURN VARCHAR2 IS
 v_raw RAW(256);
 v_hex VARCHAR2(256);
BEGIN
 v_raw := DBMS_CRYPTO.HASH(
  UTL_RAW.CAST_TO_RAW(p_password),
  DBMS_CRYPTO.HASH_SH256
 );
 v_hex := RAWTOHEX(v_raw);
 RETURN v_hex;
END;

FUNCTION validate_email(p_email VARCHAR2) RETURN NUMBER IS
BEGIN
 IF REGEXP_LIKE(p_email,'^[A-Za-z0-9._%+-]+@gmail\.com$') THEN
  RETURN 1;
 ELSE
  RETURN 0;
 END IF;
END;

PROCEDURE add_admin(p_username VARCHAR2,p_gmail VARCHAR2,p_password VARCHAR2) IS
BEGIN
 INSERT INTO Users(username,gmail,password_hash,role)
 VALUES(p_username,p_gmail,hash_password(p_password),'admin_user');
 COMMIT;
END;

PROCEDURE add_manager(p_username VARCHAR2,p_gmail VARCHAR2,p_password VARCHAR2) IS
BEGIN
 INSERT INTO Users(username,gmail,password_hash,role)
 VALUES(p_username,p_gmail,hash_password(p_password),'manager_user');
 COMMIT;
END;

PROCEDURE update_manager(p_user_id NUMBER,p_username VARCHAR2,p_gmail VARCHAR2,p_password VARCHAR2) IS
 v_hash VARCHAR2(256);
BEGIN
 IF p_password IS NOT NULL THEN
  v_hash := hash_password(p_password);
 END IF;

 UPDATE Users
 SET username=NVL(p_username,username),
     gmail=NVL(p_gmail,gmail),
     password_hash=NVL(v_hash,password_hash)
 WHERE user_id=p_user_id AND role='manager_user';

 IF SQL%ROWCOUNT=0 THEN
  RAISE_APPLICATION_ERROR(-20022,'Manager not found');
 END IF;
 COMMIT;
END;

PROCEDURE delete_manager(p_user_id NUMBER) IS
BEGIN
 DELETE FROM Users WHERE user_id=p_user_id AND role='manager_user';
 IF SQL%ROWCOUNT=0 THEN
  RAISE_APPLICATION_ERROR(-20025,'Manager not found');
 END IF;
 COMMIT;
END;

PROCEDURE get_all_managers(p_cursor OUT SYS_REFCURSOR) IS
BEGIN
 OPEN p_cursor FOR
 SELECT user_id,username,gmail,password_hash
 FROM Users WHERE role='manager_user';
END;


-- запись в джсон
PROCEDURE export_users_to_file(p_filename VARCHAR2) IS
    f UTL_FILE.FILE_TYPE;
    CURSOR c_users IS
        SELECT user_id, username, gmail, password_hash, role
        FROM Users;
    l_first BOOLEAN := TRUE;
BEGIN
    f := UTL_FILE.FOPEN('JSON_DIR', p_filename, 'w', 32767);

    UTL_FILE.PUT_LINE(f, '[');

    FOR r IN c_users LOOP
        IF NOT l_first THEN
            UTL_FILE.PUT_LINE(f, ',');
        END IF;

        UTL_FILE.PUT_LINE(f,
            '{' ||
            '"user_id":' || r.user_id || ',' ||
            '"username":"' || r.username || '",' ||
            '"gmail":"' || r.gmail || '",' ||
            '"password_hash":"' || r.password_hash || '",' ||
            '"role":"' || r.role || '"' ||
            '}'
        );

        l_first := FALSE;
    END LOOP;

    UTL_FILE.PUT_LINE(f, ']');
    UTL_FILE.FCLOSE(f);

    DBMS_OUTPUT.PUT_LINE('Export completed: ' || p_filename);
END;

-- из джисона
PROCEDURE import_users_from_file(p_filename VARCHAR2) IS
    f      UTL_FILE.FILE_TYPE;
    l_line VARCHAR2(32767);
    l_json CLOB;
BEGIN
    DBMS_LOB.CREATETEMPORARY(l_json, TRUE);

    f := UTL_FILE.FOPEN('JSON_DIR', p_filename, 'r', 32767);

    LOOP
        BEGIN
            UTL_FILE.GET_LINE(f, l_line);
            DBMS_LOB.APPEND(l_json, l_line);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
        END;
    END LOOP;

    UTL_FILE.FCLOSE(f);

    BEGIN
        INSERT INTO Users (username, gmail, password_hash, role)
        SELECT
            jt.username,
            jt.gmail,
            jt.password_hash,
            jt.role
        FROM JSON_TABLE(
            l_json,
            '$[*]'
            COLUMNS (
                username      VARCHAR2(50) PATH '$.username',
                gmail         VARCHAR2(100) PATH '$.gmail',
                password_hash VARCHAR2(200) PATH '$.password_hash',
                role          VARCHAR2(20) PATH '$.role'
            )
        ) jt;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('Skipping duplicate username or gmail');
    END;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Import completed: ' || p_filename);

    DBMS_LOB.FREETEMPORARY(l_json);
EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(f) THEN
            UTL_FILE.FCLOSE(f);
        END IF;
        RAISE_APPLICATION_ERROR(-20050, 'Error importing users: ' || SQLERRM);
END import_users_from_file;
END pkg_admin;
/

--интерфейс для манагера
CREATE OR REPLACE PACKAGE pkg_manager AS
    -- Musicians
    PROCEDURE add_musician(p_name VARCHAR2, p_info VARCHAR2);
    PROCEDURE update_musician(p_id NUMBER, p_name VARCHAR2, p_info VARCHAR2, p_status VARCHAR2 DEFAULT NULL);
    PROCEDURE get_musicians(p_cursor OUT SYS_REFCURSOR);
    PROCEDURE delete_musician(p_musician_id NUMBER);
    -- Albums
    PROCEDURE add_album(p_musician_id NUMBER, p_title VARCHAR2, p_release_date DATE, 
                        p_link VARCHAR2, p_pic_link VARCHAR2);
    PROCEDURE update_album(p_album_id NUMBER, p_musician_id NUMBER, p_title VARCHAR2, p_release_date DATE, 
                       p_link VARCHAR2, p_pic_link VARCHAR2);
    PROCEDURE delete_album(p_album_id NUMBER);
    PROCEDURE get_albums(p_cursor OUT SYS_REFCURSOR);
    -- Tracks    
    PROCEDURE add_track(p_album_id NUMBER, p_title VARCHAR2);
    PROCEDURE update_track(p_track_id NUMBER, p_title VARCHAR2);
    PROCEDURE delete_track(p_track_id NUMBER);
    PROCEDURE get_tracks(p_cursor OUT SYS_REFCURSOR);
    PROCEDURE get_tracks_by_album(p_album_id NUMBER, p_cursor OUT SYS_REFCURSOR);
    -- Votes
    PROCEDURE delete_vote(p_vote_id NUMBER);
    PROCEDURE get_votes(p_cursor OUT SYS_REFCURSOR);
    --Nominants
    PROCEDURE get_nominants(p_cursor OUT SYS_REFCURSOR);
    PROCEDURE add_nominant(p_award_id NUMBER, p_album_id NUMBER);
    -- Awards
    PROCEDURE get_awards(p_cursor OUT SYS_REFCURSOR);
    PROCEDURE update_award(p_award_id NUMBER, p_name VARCHAR2, p_description VARCHAR2);
    
    PROCEDURE calculate_winners;
    PROCEDURE get_top_musicians(p_cursor OUT SYS_REFCURSOR);
    PROCEDURE get_winners_count(p_count OUT NUMBER);
END pkg_manager;
/

CREATE OR REPLACE PACKAGE BODY pkg_manager AS

  -- Возвращает общее количество победителей
  PROCEDURE get_winners_count(p_count OUT NUMBER) IS
  BEGIN
    SELECT COUNT(*) INTO p_count FROM Winners;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20090, 'Ошибка при подсчёте победителей: ' || SQLERRM);
  END;

  -- Добавляет нового музыканта
  PROCEDURE add_musician(p_name VARCHAR2, p_info VARCHAR2) IS
  BEGIN
    INSERT INTO Musicians(name, info, status)
    VALUES (p_name, p_info, 'participating');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20010, 'Error adding musician: ' || SQLERRM);
  END;

  -- Обновляет данные музыканта
  PROCEDURE update_musician(
    p_id NUMBER,
    p_name VARCHAR2,
    p_info VARCHAR2,
    p_status VARCHAR2
  ) IS
  BEGIN
    UPDATE Musicians
    SET name = p_name, info = p_info, status = NVL(p_status, status)
    WHERE musician_id = p_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20011, 'Musician not found: ' || p_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20012, 'Error updating musician: ' || SQLERRM);
  END;

  -- Удаляет музыканта
  PROCEDURE delete_musician(p_musician_id NUMBER) IS
  BEGIN
    DELETE FROM Musicians WHERE musician_id = p_musician_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20060, 'Musician not found: ' || p_musician_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20061, 'Error deleting musician: ' || SQLERRM);
  END;


  -- Возвращает список всех музыкантов
  PROCEDURE get_musicians(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT musician_id, name, info, status FROM Musicians;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20015, 'Error fetching musicians: ' || SQLERRM);
  END;


  -- Добавляет новый альбом
  PROCEDURE add_album(
    p_musician_id NUMBER,
    p_title VARCHAR2,
    p_release_date DATE,
    p_link VARCHAR2,
    p_pic_link VARCHAR2
  ) IS
    v_link VARCHAR2(200);
    v_pic_link VARCHAR2(100);
  BEGIN
    v_link := NVL(p_link, 'https://open.spotify.com/track/2NqCUYqbMgHsDmSxJMTjBa?si=1c31c957ff394ec9');
    v_pic_link := NVL(p_pic_link, '/img/DBimg/test.jpg');

    INSERT INTO Albums(musician_id, title, release_date, link, pic_link)
    VALUES (p_musician_id, p_title, p_release_date, v_link, v_pic_link);
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20020, 'Error adding album: ' || SQLERRM);
  END;


  -- Обновляет данные альбома
  PROCEDURE update_album(
    p_album_id NUMBER,
    p_musician_id NUMBER,
    p_title VARCHAR2,
    p_release_date DATE,
    p_link VARCHAR2,
    p_pic_link VARCHAR2
  ) IS
  BEGIN
    UPDATE Albums
    SET title = p_title, release_date = p_release_date, link = p_link, pic_link = p_pic_link
    WHERE album_id = p_album_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20021, 'Album not found: ' || p_album_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20022, 'Error updating album: ' || SQLERRM);
  END;


  -- Удаляет альбом
  PROCEDURE delete_album(p_album_id NUMBER) IS
  BEGIN
    DELETE FROM Albums WHERE album_id = p_album_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20023, 'Album not found: ' || p_album_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20024, 'Error deleting album: ' || SQLERRM);
  END;


  -- Возвращает список всех альбомов
  PROCEDURE get_albums(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT album_id, musician_id, title,
             TO_CHAR(release_date, 'YYYY-MM-DD') AS release_date,
             link, pic_link
      FROM Albums;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20025, 'Error fetching albums: ' || SQLERRM);
  END;


  -- Возвращает список всех треков с альбомами и музыкантами
  PROCEDURE get_tracks(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT t.track_id, t.album_id, t.title,
             a.title AS album_title,
             m.name AS musician_name
      FROM Music t
      JOIN Albums a ON t.album_id = a.album_id
      JOIN Musicians m ON a.musician_id = m.musician_id
      ORDER BY t.track_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20036, 'Error fetching all tracks: ' || SQLERRM);
  END;


  -- Добавляет трек в альбом
  PROCEDURE add_track(p_album_id NUMBER, p_title VARCHAR2) IS
  BEGIN
    INSERT INTO Music(album_id, title)
    VALUES (p_album_id, p_title);
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20030, 'Error adding track: ' || SQLERRM);
  END;


  -- Обновляет название трека
  PROCEDURE update_track(p_track_id NUMBER, p_title VARCHAR2) IS
  BEGIN
    UPDATE Music SET title = p_title WHERE track_id = p_track_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20031, 'Track not found: ' || p_track_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20032, 'Error updating track: ' || SQLERRM);
  END;


  -- Удаляет трек
  PROCEDURE delete_track(p_track_id NUMBER) IS
  BEGIN
    DELETE FROM Music WHERE track_id = p_track_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20033, 'Track not found: ' || p_track_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20034, 'Error deleting track: ' || SQLERRM);
  END;


  -- Возвращает треки конкретного альбома
  PROCEDURE get_tracks_by_album(p_album_id NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT track_id, title FROM Music WHERE album_id = p_album_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20035, 'Error fetching tracks: ' || SQLERRM);
  END;


  -- Удаляет голос
  PROCEDURE delete_vote(p_vote_id NUMBER) IS
  BEGIN
    DELETE FROM Votes WHERE vote_id = p_vote_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20040, 'Vote not found: ' || p_vote_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20041, 'Error deleting vote: ' || SQLERRM);
  END;


  -- Возвращает список всех голосов
  PROCEDURE get_votes(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT vote_id, user_id, award_id, album_id, comment_text FROM Votes;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20042, 'Error fetching votes: ' || SQLERRM);
  END;


  -- Возвращает список номинантов
  PROCEDURE get_nominants(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT n.award_id, a.award_name, n.album_id,
             alb.title AS album_title,
             m.name AS musician_name
      FROM Nominants n
      JOIN Awards a ON n.award_id = a.award_id
      JOIN Albums alb ON n.album_id = alb.album_id
      JOIN Musicians m ON alb.musician_id = m.musician_id
      ORDER BY a.award_name, m.name, alb.title;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20070, 'Error fetching nominants: ' || SQLERRM);
  END;


  -- Добавляет альбом в номинацию
  PROCEDURE add_nominant(p_award_id NUMBER, p_album_id NUMBER) IS
  BEGIN
    INSERT INTO Nominants(award_id, album_id)
    VALUES (p_award_id, p_album_id);
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      RAISE_APPLICATION_ERROR(-20076, 'Error adding nominant: This album is already nominated for this award.');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20077, 'Error adding nominant: ' || SQLERRM);
  END;


  -- Возвращает список наград
  PROCEDURE get_awards(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT award_id, award_name, award_description FROM Awards;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20050, 'Error fetching awards: ' || SQLERRM);
  END;


  -- Обновляет данные награды
  PROCEDURE update_award(p_award_id NUMBER, p_name VARCHAR2, p_description VARCHAR2) IS
  BEGIN
    UPDATE Awards
    SET award_name = p_name, award_description = p_description
    WHERE award_id = p_award_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20051, 'Award not found: ' || p_award_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20052, 'Error updating award: ' || SQLERRM);
  END;


  -- Пересчитывает победителей по количеству голосов
  PROCEDURE calculate_winners IS
  BEGIN
    DELETE FROM Winners;

    INSERT INTO Winners(award_id, album_id, musician_id)
    SELECT r.award_id, r.album_id, a.musician_id
    FROM AlbumRatings r
    JOIN Albums a ON r.album_id = a.album_id
    WHERE (r.award_id, r.votes_count) IN (
      SELECT award_id, MAX(votes_count)
      FROM AlbumRatings
      GROUP BY award_id
    );

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20080, 'Ошибка расчёта победителей: ' || SQLERRM);
  END;


  -- Возвращает топ музыкантов по количеству голосов
  PROCEDURE get_top_musicians(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT w.album_id, w.musician_id, COUNT(v.vote_id) AS vote_count
      FROM Winners w
      LEFT JOIN Votes v ON w.album_id = v.album_id
      GROUP BY w.album_id, w.musician_id
      ORDER BY vote_count DESC;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20054, 'Error fetching top musicians: ' || SQLERRM);
  END;

END pkg_manager;
/

--ИНТЕрфейс для геста
CREATE OR REPLACE PACKAGE pkg_guest AS
  --функции
  FUNCTION hash_password(p_password VARCHAR2) RETURN VARCHAR2;
  FUNCTION validate_email(p_email VARCHAR2) RETURN NUMBER;
  --процедуры
  PROCEDURE vote_for_album(p_user_id NUMBER, p_award_id NUMBER, p_album_id NUMBER, p_comment_text VARCHAR2);
  PROCEDURE register_user(p_username IN VARCHAR2, p_gmail IN VARCHAR2, p_password_hash IN VARCHAR2);
  PROCEDURE login_user(p_username IN VARCHAR2, p_password_hash IN VARCHAR2, p_user_id OUT NUMBER, p_role OUT VARCHAR2);
  PROCEDURE get_awards(p_cursor OUT SYS_REFCURSOR);
  PROCEDURE get_albums_by_award(p_award_id NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE get_user_vote(p_user_id IN votes.user_id%TYPE, p_award_id IN votes.award_id%TYPE, p_album_id OUT votes.album_id%TYPE);
  PROCEDURE get_comments_by_album(p_album_id IN votes.album_id%TYPE, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE get_album_description(p_album_id IN albums.album_id%TYPE, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE get_tracks_by_album(p_album_id NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE get_winners(p_cursor OUT SYS_REFCURSOR);
END pkg_guest;
/


CREATE OR REPLACE PACKAGE BODY pkg_guest AS

  -- Хэширует пароль
  FUNCTION hash_password(p_password VARCHAR2) RETURN VARCHAR2 IS
    v_raw RAW(256);
    v_hex VARCHAR2(256);
  BEGIN
    v_raw := DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(p_password), DBMS_CRYPTO.HASH_SH256);
    v_hex := RAWTOHEX(v_raw);
    RETURN v_hex;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21000, 'Error hashing password: ' || SQLERRM);
  END;

  -- Проверяет валидность Gmail
  FUNCTION validate_email(p_email VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@gmail\.com$') THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21001, 'Error validating email: ' || SQLERRM);
  END;

  -- Голосует за альбом
  PROCEDURE vote_for_album(p_user_id NUMBER, p_award_id NUMBER, p_album_id NUMBER, p_comment_text VARCHAR2) IS
    v_dummy NUMBER;
  BEGIN
    SELECT 1 INTO v_dummy FROM Nominants WHERE award_id = p_award_id AND album_id = p_album_id;
    INSERT INTO Votes(award_id, album_id, user_id, comment_text)
    VALUES(p_award_id, p_album_id, p_user_id, NVL(p_comment_text,''));
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20010, 'This album does not participate in this nomination.');
    WHEN DUP_VAL_ON_INDEX THEN
      RAISE_APPLICATION_ERROR(-20011, 'User has already voted for this award.');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20012, 'Voting is closed ' || SQLERRM);
  END;

  -- Регистрирует нового пользователя
  PROCEDURE register_user(p_username IN VARCHAR2, p_gmail IN VARCHAR2, p_password_hash IN VARCHAR2) IS
  BEGIN
    INSERT INTO Users(username, gmail, password_hash, role) VALUES(p_username, p_gmail, p_password_hash, 'guest_user');
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      RAISE_APPLICATION_ERROR(-21020, 'Username or Gmail already exists.');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21021, 'Error registering user: ' || SQLERRM);
  END;

  -- Авторизация пользователя
  PROCEDURE login_user(p_username IN VARCHAR2, p_password_hash IN VARCHAR2, p_user_id OUT NUMBER, p_role OUT VARCHAR2) IS
  BEGIN
    SELECT user_id, role INTO p_user_id, p_role
    FROM Users
    WHERE username = p_username AND password_hash = p_password_hash;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-21030, 'Invalid username or password.');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21031, 'Error during login: ' || SQLERRM);
  END;

  -- Получает список наград
  PROCEDURE get_awards(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR SELECT award_id, award_name, award_description FROM Awards;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21040, 'Error fetching awards: ' || SQLERRM);
  END;

  -- Получает список альбомов по награде
  PROCEDURE get_albums_by_award(p_award_id NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT a.album_id, a.musician_id, m.name AS musician_name, 
             a.title, TO_CHAR(a.release_date, 'YYYY-MM-DD') as release_date, 
             a.link, a.pic_link
      FROM Albums a
      JOIN Nominants n ON a.album_id = n.album_id
      JOIN Musicians m ON a.musician_id = m.musician_id
      WHERE n.award_id = p_award_id AND m.status = 'participating';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21041, 'Error fetching albums by award: ' || SQLERRM);
  END;

  -- Получает голос пользователя для конкретной награды
  PROCEDURE get_user_vote(p_user_id IN votes.user_id%TYPE, p_award_id IN votes.award_id%TYPE, p_album_id OUT votes.album_id%TYPE) IS
  BEGIN
    SELECT album_id INTO p_album_id FROM Votes WHERE user_id = p_user_id AND award_id = p_award_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_album_id := NULL;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21042, 'Error fetching user vote: ' || SQLERRM);
  END;

  -- Получает комментарии к альбому
  PROCEDURE get_comments_by_album(p_album_id IN votes.album_id%TYPE, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT u.username, v.comment_text
      FROM Votes v
      JOIN Users u ON v.user_id = u.user_id
      WHERE v.album_id = p_album_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21043, 'Error fetching comments: ' || SQLERRM);
  END;

  -- Получает описание альбома
  PROCEDURE get_album_description(p_album_id IN albums.album_id%TYPE, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT a.album_id, a.musician_id, m.name, m.info, a.title,
             TO_CHAR(a.release_date, 'YYYY-MM-DD') as release_date, a.link, a.pic_link
      FROM Albums a
      JOIN Musicians m ON a.musician_id = m.musician_id
      WHERE a.album_id = p_album_id AND m.status = 'participating';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21044, 'Error fetching album description: ' || SQLERRM);
  END;

  -- Получает треки альбома
  PROCEDURE get_tracks_by_album(p_album_id NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT t.track_id, t.title
      FROM Music t
      JOIN Albums a ON t.album_id = a.album_id
      JOIN Musicians m ON a.musician_id = m.musician_id
      WHERE t.album_id = p_album_id AND m.status = 'participating';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-21045, 'Error fetching tracks: ' || SQLERRM);
  END;

  -- Получает список победителей
  PROCEDURE get_winners(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT w.award_id, aw.award_name, w.album_id, al.title AS album_title, w.musician_id, m.name AS musician_name, al.pic_link
      FROM Winners w
      JOIN Awards aw ON aw.award_id = w.award_id
      JOIN Albums al ON al.album_id = w.album_id
      JOIN Musicians m ON m.musician_id = w.musician_id
      ORDER BY w.award_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20110, 'Error fetching winners: ' || SQLERRM);
  END;

END pkg_guest;
/