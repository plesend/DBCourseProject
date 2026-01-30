--триггер, чтобы подсчитать рейтинг
CREATE OR REPLACE TRIGGER admin_user.trg_vote_insert
AFTER INSERT ON admin_user.Votes
FOR EACH ROW
DECLARE
BEGIN
    MERGE INTO admin_user.AlbumRatings ar
    USING (SELECT :NEW.album_id AS album_id, :NEW.award_id AS award_id FROM dual) src
    ON (ar.album_id = src.album_id AND ar.award_id = src.award_id)
    WHEN MATCHED THEN
        UPDATE SET ar.votes_count = ar.votes_count + 1
    WHEN NOT MATCHED THEN
        INSERT (album_id, award_id, votes_count)
        VALUES (src.album_id, src.award_id, 1);
END;
/

-- голосовать нельзя после подсчета победитеоей
CREATE OR REPLACE TRIGGER trg_block_votes_after_winners
BEFORE INSERT ON Votes
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Winners;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20120,
            'Voting is closed. Winners have already been determined.'
        );
    END IF;
END;
/

--один музыкант не может иметь более двух альбомов в сумме за все номинации
CREATE OR REPLACE TRIGGER trg_album_limit
BEFORE INSERT ON Albums
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Albums a
    JOIN Nominants n ON a.album_id = n.album_id
    WHERE a.musician_id = :NEW.musician_id;

    IF v_count >= 2 THEN
        RAISE_APPLICATION_ERROR(-20001, 'This musician already has 2 albums in nominations.');
    END IF;
END;
/

-- при равенстве голосов выбирается рандомный победитель
CREATE OR REPLACE TRIGGER trg_winner_random
BEFORE INSERT ON Winners
FOR EACH ROW
DECLARE
    v_max_votes NUMBER;
    v_count NUMBER;
    v_random_album_id NUMBER;
BEGIN
    SELECT MAX(votes_count) INTO v_max_votes
    FROM AlbumRatings
    WHERE award_id = :NEW.award_id;

    SELECT COUNT(*) INTO v_count
    FROM AlbumRatings
    WHERE award_id = :NEW.award_id
      AND votes_count = v_max_votes;

    IF v_count > 1 THEN
        SELECT album_id INTO v_random_album_id
        FROM (SELECT album_id FROM AlbumRatings WHERE award_id = :NEW.award_id AND votes_count = v_max_votes ORDER BY DBMS_RANDOM.VALUE)
        WHERE ROWNUM = 1;
        :NEW.album_id := v_random_album_id;
    END IF;
END;
/
