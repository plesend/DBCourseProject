const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const oracledb = require('oracledb');
const path = require('path');

const app = express();
const PORT = 3000;

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'frontend')));

app.use(session({
    secret: 'some_secret_key',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 3600000 } 
}));

const dbConfig = {
  guest: {
    user: 'guest_user',
    password: 'Kate2006',
    connectString: 'localhost:1521/FREEPDB1'
  },
  manager: {
    user: 'manager_user',
    password: 'Kate2006',
    connectString: 'localhost:1521/FREEPDB1'
  },
  admin: {
    user: 'admin_user',
    password: 'Kate2006',
    connectString: 'localhost:1521/FREEPDB1'
  }
};
app.get('/api/hasCalculatedWinners', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);

    const result = await connection.execute(
      `BEGIN pkg_manager.get_winners_count(:count); END;`,
      { count: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER } }
    );

    const count = result.outBinds.count;
    res.json({ success: count > 0 });

  } catch (err) {
    console.error('Error checking winners:', err);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (e) { console.error(e); }
    }
  }
});

function ensureGuest(req, res, next) {
  if(!req.session.user) {
    return res.redirect('/login');
  }
  if(req.session.user.role !== 'guest_user') {
    return res.status(403).send('Access denied');
  }
  next();
}

function ensureAdminOrManager(req, res, next) {
  if(!req.session.user) {
    return res.redirect('/login');
  }
  if(req.session.user.role === 'guest_user') {
    return res.status(403).send('Access denied');
  }
  next();
}

app.get('/', (req, res) => res.redirect('/login'));
app.get('/login', (req, res) => res.sendFile(path.join(__dirname, 'frontend', 'login.html')));
app.get('/register', (req, res) => res.sendFile(path.join(__dirname, 'frontend', 'register.html')));
app.get('/awards', ensureGuest, (req, res) => {
    if (!req.session.user) return res.redirect('/login');
    res.sendFile(path.join(__dirname, 'frontend', 'awards.html'));
});
app.get('/award/:id', ensureGuest,(req, res) => {
  res.sendFile(path.join(__dirname, 'frontend', 'award.html'));
});
app.get('/adminpanel', ensureAdminOrManager, (req, res) => {
  if (!req.session.user) return res.redirect('/login');
  res.sendFile(path.join(__dirname, 'frontend', 'adminpanel.html'));
});
app.get('/api/user-info', (req, res) => {
  if (!req.session.user) return res.json({ user: null });
  res.json({user: req.session.user });
})
app.get('/album/:albumId', ensureGuest, (req, res) => {
  res.sendFile(path.join(__dirname, 'frontend', 'album.html'));
})
app.post('/api/logout', (req, res) => {
  req.session.destroy(err => {
    if (err) {
      console.error(err);
      return res.status(500).json({ error: 'Logout failed' });
    }

    res.clearCookie('connect.sid'); 
    res.json({ success: true });
  });
});

app.get('/api/has-voted/:awardId', async (req, res) => {
  if(!req.session.user) {
    return res.json({
      hasVoted : false,
      canVote: false
    })
  }
  const userId = req.session.user.id;
  const awardId = Number(req.params.awardId);
  let connection;
  try{
      connection = await oracledb.getConnection(dbConfig.guest);
       const result = await connection.execute(
      `
      BEGIN
        pkg_guest.get_user_vote(
          :p_user_id,
          :p_award_id,
          :p_album_id
        );
      END;
      `,
      {
        p_user_id: userId,
        p_award_id: awardId,
        p_album_id: {
          dir: oracledb.BIND_OUT,
          type: oracledb.NUMBER
        }
      }
    );

    const votedAlbumId = result.outBinds.p_album_id;

    
    if (votedAlbumId !== null) {
      return res.json({
        hasVoted: true,
        canVote: false,
        votedAlbumId
      });
    }

    res.json({
      hasVoted: false,
      canVote: true
    });
  } catch (e) {
    res.status(500).json({ error: 'Database error' });
  }
  finally {
    if(connection) connection.close();
  }

});

app.post('/register', async (req, res) => {
  const { username, gmail, password } = req.body;
  let connection;

  try {
    connection = await oracledb.getConnection(dbConfig.guest);

    const hashResult = await connection.execute(
      `BEGIN :hash := pkg_guest.hash_password(:pwd); END;`,
      {
        hash: { dir: oracledb.BIND_OUT, type: oracledb.STRING },
        pwd: password
      }
    );
    const password_hash = hashResult.outBinds.hash;

    await connection.execute(
      `BEGIN
          pkg_guest.register_user(
              p_username => :username,
              p_gmail => :gmail,
              p_password_hash => :pwd_hash
          );
      END;`,
      { username, gmail, pwd_hash: password_hash }
    );

    await connection.commit();
    res.send({ message: 'Registration successful!' });

  } catch (err) {
    console.error("Oracle error full:", err);
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      const code = Number(match[1]);
      const message = match[2];
      res.status(400).json({ error_code: code, message });
    } else {
      res.status(500).json({ error: err.message });
    }

  } finally {
    if (connection) await connection.close();
  }
});


app.post('/login', async (req, res) => {
    const { username, password } = req.body;

    try {
        const connection = await oracledb.getConnection(dbConfig.guest);

        const hashResult = await connection.execute(
            `BEGIN :hash := pkg_guest.hash_password(:pwd); END;`,
            {
                hash: { dir: oracledb.BIND_OUT, type: oracledb.STRING },
                pwd: password
            }
        );
        const password_hash = hashResult.outBinds.hash;

        const result = await connection.execute(
            `DECLARE
                v_user_id NUMBER;
                v_role VARCHAR2(20);
             BEGIN
                pkg_guest.login_user(:username, :pwd_hash, v_user_id, v_role);
                :out_id := v_user_id;
                :out_role := v_role;
             END;`,
            {
                username,
                pwd_hash: password_hash,
                out_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
                out_role: { dir: oracledb.BIND_OUT, type: oracledb.STRING }
            }
        );

        await connection.close();

        req.session.user = {
            id: result.outBinds.out_id,
            username,
            role: result.outBinds.out_role
        };

        res.json({ message: 'Login successful', user: req.session.user });
    } catch (err) {
        console.error(err);
        res.status(401).send({ error: err.message });
    }
});

app.get('/api/awards', async (req, res) => {
  let connection;

  try {
    connection = await oracledb.getConnection(dbConfig.guest);

    const result = await connection.execute(
      `BEGIN pkg_guest.get_awards(:cursor); END;`,
      { cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } }
    );

    const resultSet = result.outBinds.cursor;

    const rows = await resultSet.getRows(); 
    const metaData = resultSet.metaData;

    await resultSet.close();

    console.log('Rows from DB:', rows);
    rows.forEach(r => console.log('award_description length:', r[2]?.length));

    res.json({
      columns: metaData.map(c => c.name),
      rows
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (err) {}
    }
  }
});

app.get('/api/award/:id', async (req, res) => {
  const awardId = Number(req.params.id); 
  let connection;

  try {
    connection = await oracledb.getConnection(dbConfig.guest);

    const result = await connection.execute(
      `BEGIN pkg_guest.get_albums_by_award(:award_id, :cursor); END;`,
      { award_id: awardId, cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } }
    );

    const rs = result.outBinds.cursor;
    const rows = await rs.getRows();
    const meta = rs.metaData;

    await rs.close();

    res.json({ columns: meta.map(c => c.name), rows });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (err) {}
    }
  }
});

app.post('/api/vote', async(req, res) => {
  let connection = await oracledb.getConnection(dbConfig.guest);
  console.log(req.body)
  const {awardId, albumId, comment} = req.body;
  const user_id = req.session.user.id;
  const award_id = Number(awardId);

  await connection.execute(
    `BEGIN
        pkg_guest.vote_for_album(
          :p_user_id,
          :p_award_id,
          :p_album_id,
          :p_comment
        );
     END;`,
    {
      p_user_id: user_id,
      p_award_id: award_id,
      p_album_id: albumId,
      p_comment: comment || ''
    }
  );

  await connection.commit();
  res.json({success: true});
})

app.get('/api/admin-music', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const result = await connection.execute(
      `BEGIN pkg_manager.get_tracks(:p_cursor); END;`,
      { p_cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } } 
    );
    
    const rs = result.outBinds.p_cursor; 
    
    const rows = await rs.getRows();
    const columns = rs.metaData.map(c => c.name);
    await rs.close();
    res.json({ columns, rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (connection) try { await connection.close(); } catch {}
  }
});

app.get('/api/admin-musicians', async (req, res) => {
  let connection;

  try {
    connection = await oracledb.getConnection(dbConfig.manager);

    const result = await connection.execute(
      `BEGIN pkg_manager.get_musicians(:cursor); END;`,
      { cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } }
    );

    const rs = result.outBinds.cursor;
    const rows = await rs.getRows();
    const columns = await rs.metaData.map(c=> c.name);
    await rs.close();
    res.json({ columns, rows });
  }
  catch (err) {
    res.status(500).json({ error: err.message }); 
  }
  finally {
    if (connection) try { 
      await connection.close(); 
    } catch {}
  }
});

app.get('/api/admin-albums', async (req, res) => {
    let connection;
    try {
        connection = await oracledb.getConnection(dbConfig.manager);
        const result = await connection.execute(
            `BEGIN pkg_manager.get_albums(:cursor); END;`,
            { cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } }
        );

        const rs = result.outBinds.cursor;
        const rows = await rs.getRows();
        const columns = rs.metaData.map(c => c.name);
        await rs.close();
        res.json({ columns, rows });
    } catch (err) { res.status(500).json({ error: err.message }); }
    finally { if (connection) try { await connection.close(); } catch {} }
});

app.get('/api/admin-votes', async (req, res) => {
    let connection;
    try {
        connection = await oracledb.getConnection(dbConfig.manager);
        const result = await connection.execute(
          `BEGIN pkg_manager.get_votes(:cursor); END;`,
          {
            cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
          }
        );

        const rs = result.outBinds.cursor;
        const rows = await rs.getRows();
        const columns = rs.metaData.map(c => c.name);
        await rs.close();
        res.json({ columns, rows });
    } catch (err) { res.status(500).json({ error: err.message }); }
    finally { if (connection) try { await connection.close(); } catch {} }
});

app.post('/api/delete-vote', async(req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    console.log(req.body);
    let {voteId} = req.body;
    voteId = Number(voteId);
    console.log(voteId);
    connection.execute(`BEGIN pkg_manager.delete_vote(:p_vote_id); end;`, {p_vote_id: voteId});
    await connection.commit();
    res.json({ success: true});

  } catch (err) {
      console.error("Error deleting nominant:", err);
        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
        
        if (match) {
            res.status(400).json({ 
                error_code: Number(match[1]), 
                message: match[2].trim()
            });
        } else {
            res.status(500).json({ error: "Server error or connection failed" });
        }
    } finally {
        if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
        }
    }
  
});

app.get('/api/admin-awards', async (req, res) => {
    let connection;
    try {
        connection = await oracledb.getConnection(dbConfig.manager);
        const result = await connection.execute(
            `BEGIN pkg_manager.get_awards(:cursor); END;`,
            { cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } }
        );

        const rs = result.outBinds.cursor;
        const rows = await rs.getRows();
        const columns = rs.metaData.map(c => c.name);
        await rs.close();
        res.json({ columns, rows });
    } catch (err) { res.status(500).json({ error: err.message }); }
    finally { if (connection) try { await connection.close(); } catch {} }
});
app.get('/api/admin-nominants', async (req, res) => {
    let connection;
    try {
        connection = await oracledb.getConnection(dbConfig.manager);
        const result = await connection.execute(
            `BEGIN pkg_manager.get_nominants(:cursor); END;`,
            {
                cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
            }
        );
        const rs = result.outBinds.cursor;
        const rows = await rs.getRows();
        const columns = rs.metaData.map(c => c.name);

        await rs.close();
        
        res.json({
            columns: columns,
            rows: rows
        });

    } catch (err) {
        console.error("Error fetching nominants:", err);
        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
        
        if (match) {
            res.status(400).json({ 
                error_code: Number(match[1]), 
                message: match[2].trim() 
            });
        } else {
            res.status(500).json({ error: "Server error or connection failed" });
        }
    } finally {
        if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
        }
    }
});

//app.post('/api/update-nominant', async (req, res) => {
//    let connection;
//    try {
//        const { oldAwardId, oldAlbumId, newAwardId, newAlbumId } = req.body;
//        const p_old_award_id = Number(oldAwardId);
//        const p_old_album_id = Number(oldAlbumId);
//        const p_new_award_id = newAwardId ? Number(newAwardId) : null;
//        const p_new_album_id = newAlbumId ? Number(newAlbumId) : null;
//
//        connection = await oracledb.getConnection(dbConfig.manager);
//
//        await connection.execute(
//            `BEGIN pkg_manager.update_nominant(:p_old_award_id, :p_old_album_id, :p_new_award_id, :p_new_album_id); END;`,
//            { 
//                p_old_award_id: p_old_award_id, 
//                p_old_album_id: p_old_album_id,
//                p_new_award_id: p_new_award_id,
//                p_new_album_id: p_new_album_id
//            }
//        );
//        
//        await connection.commit();
//        res.json({ success: true, message: 'Nominant updated successfully.' });
//
//    } catch (err) {
//        console.error("Error updating nominant:", err);
//        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
//        
//        if (match) {
//            res.status(400).json({ 
//                error_code: Number(match[1]), 
//                message: match[2].trim()
//            });
//        } else {
//            res.status(500).json({ error: "Server error or connection failed" });
//        }
//    } finally {
//        if (connection) {
//            try {
//                await connection.close();
//            } catch (closeErr) {
//                console.error("Error closing connection:", closeErr);
//            }
//        }
//    }
//});

app.post('/api/add-nominant', async (req, res) => {
    let connection;
    try {
        console.log(req.body);
        const { awardId, albumId } = req.body;

        const p_award_id = Number(awardId);
        const p_album_id = Number(albumId);

        if (isNaN(p_award_id) || isNaN(p_album_id)) {
            return res.status(400).json({ error: "Award ID and Album ID must be numbers." });
        }

        connection = await oracledb.getConnection(dbConfig.manager);

        await connection.execute(
            `BEGIN pkg_manager.add_nominant(:p_award_id, :p_album_id); END;`,
            { 
                p_award_id: p_award_id, 
                p_album_id: p_album_id
            }
        );
        
        await connection.commit();
        res.json({ success: true, message: 'Nominant added successfully.' });

    } catch (err) {
        console.error("Error adding nominant:", err);
        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
        
        if (match) {
            res.status(400).json({ 
                error_code: Number(match[1]), 
                message: match[2].trim()
            });
        } else {
            res.status(500).json({ error: "Server error or connection failed" });
        }

    } finally {
        if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
        }
    }
});

//app.post('/api/delete-nominant', async (req, res) => {
//    let connection;
//    try {
//        const { awardId, albumId } = req.body;
//        const p_award_id = Number(awardId);
//        const p_album_id = Number(albumId);
//
//        connection = await oracledb.getConnection(dbConfig.manager);
//
//        await connection.execute(
//            `BEGIN pkg_manager.delete_nominant(:p_award_id, :p_album_id); END;`,
//            { 
//                p_award_id: p_award_id, 
//                p_album_id: p_album_id 
//            }
//        );
//        
//        await connection.commit();
//        res.json({ success: true, message: 'Nominant deleted successfully.' });
//
//    } catch (err) {
//        console.error("Error deleting nominant:", err);
//        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
//        
//        if (match) {
//            res.status(400).json({ 
//                error_code: Number(match[1]), 
//                message: match[2].trim()
//            });
//        } else {
//            res.status(500).json({ error: "Server error or connection failed" });
//        }
//    } finally {
//        if (connection) {
//            try {
//                await connection.close();
//            } catch (closeErr) {
//                console.error("Error closing connection:", closeErr);
//            }
//        }
//    }
//});

app.get('/api/winners', async (req, res) => {
  let connection;

  try {
    connection = await oracledb.getConnection(dbConfig.guest);

    const result = await connection.execute(
      `BEGIN pkg_guest.get_winners(:cursor); END;`,
      {
        cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
      }
    );

    const rs = result.outBinds.cursor;

    const rows = await rs.getRows();          
    const columns = rs.metaData.map(m => m.name);

    await rs.close();

    res.json({
      success: true,
      columns,
      rows
    });

  } catch (err) {
    console.error('Error fetching winners:', err);

    const match = err.message?.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({
        success: false,
        error_code: Number(match[1]),
        message: match[2].trim()
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Error fetching winners'
      });
    }

  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch (e) {
        console.error('Error closing connection:', e);
      }
    }
  }
});


app.get('/api/calculate-winners', async(req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    await connection.execute(`BEGIN pkg_manager.calculate_winners; END;`);
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    console.error("Error updating manager:", err);
        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
        
        if (match) {
            res.status(400).json({ 
                error_code: Number(match[1]), 
                message: match[2].trim() 
            });
        } else {
            res.status(500).json({ error: "Server error or connection failed" });
        }
  } finally {
    if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
        }
  }
})

app.get('/api/admin-managers', async (req, res) => {
  let connection;
    try {
        connection = await oracledb.getConnection(dbConfig.admin);
        const result = await connection.execute(
            `BEGIN pkg_admin.get_all_managers(:cursor); END;`,
            {
                cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
            }
        );

        const rs = result.outBinds.cursor;
        const rows = await rs.getRows();  
        const meta = rs.metaData.map(m => m.name); 

        await rs.close();

        res.json({
            columns: meta,
            rows
        });

    } catch (err) {
        res.status(500).json({ error: err.message });
    } finally {
      if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
          }
    }
});

app.post('/api/update-manager', async (req, res) => {
    let connection; 
    try {
        const { user_id, username, gmail, password } = req.body;
        const p_user_id = Number(user_id);
        
        connection = await oracledb.getConnection(dbConfig.admin);

        await connection.execute(
            `BEGIN pkg_admin.update_manager(:p_user_id, :p_username, :p_gmail, :p_password); END;`,
            { 
                p_user_id: p_user_id, 
                p_username: username, 
                p_gmail: gmail, 
                p_password: password 
            }
        );
        
        await connection.commit();
        res.json({ success: true });

    } catch (err) {
        console.error("Error updating manager:", err);
        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
        
        if (match) {
            res.status(400).json({ 
                error_code: Number(match[1]), 
                message: match[2].trim() 
            });
        } else {
            res.status(500).json({ error: "Server error or connection failed" });
        }
    } finally {
        if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
        }
    }
});

app.post('/api/delete-manager', async (req, res) => {
    let connection; 
    try {
        const { user_id } = req.body;
        
        const p_user_id = Number(user_id);
        
        connection = await oracledb.getConnection(dbConfig.admin);

        await connection.execute(
            `BEGIN pkg_admin.delete_manager(:p_user_id); END;`,
            { p_user_id: p_user_id }
        );
        
        await connection.commit();
        res.json({ success: true, message: 'Manager deleted successfully.' });

    } catch (err) {
        console.error("Error deleting manager:", err);
        const match = err.message ? err.message.match(/ORA-(\d+): (.+)/) : null;
        
        if (match) {
            res.status(400).json({ 
                error_code: Number(match[1]), 
                message: match[2].trim()
            });
        } else {
            res.status(500).json({ error: "Server error or connection failed" });
        }

    } finally {
        if (connection) {
            try {
                await connection.close();
            } catch (closeErr) {
                console.error("Error closing connection:", closeErr);
            }
        }
    }
});
app.post('/api/add-manager', async (req, res)=> {
  let connection = await oracledb.getConnection(dbConfig.admin);
  const {username, gmail, password} = req.body;
  await connection.execute(
      `BEGIN pkg_admin.add_manager(:p_username, :p_gmail, :p_password); END;`,
      { p_username: username, p_gmail: gmail, p_password: password }
    );

  await connection.commit();
  res.json({success:true});
});

app.post('/api/add-musician', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { name, info } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.add_musician(:p_name, :p_info); END;`,
      { p_name: name, p_info: info }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/update-musician', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    console.log(req.body);
    const { musicianId, name, info, status } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.update_musician(:p_id, :p_name, :p_info, :p_status); END;`,
      { p_id: musicianId, p_name: name, p_info: info, p_status: status }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/delete-musician', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { musicianId } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.delete_musician(:p_musician_id); END;`,
      { p_musician_id: musicianId }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/add-track', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { albumId, title } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.add_track(:p_album_id, :p_title); END;`,
      { p_album_id: albumId, p_title: title }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/update-track', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { trackId, title } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.update_track(:p_track_id, :p_title); END;`,
      { p_track_id: trackId, p_title: title }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/delete-track', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { trackId } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.delete_track(:p_track_id); END;`,
      { p_track_id: trackId }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/add-album', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { title, musicianId, releaseDate, link, picLink } = req.body;
    const nummusicianId = Number(musicianId);
    const orareleaseDate = new Date(releaseDate);
    await connection.execute(
      `BEGIN pkg_manager.add_album(:p_musician_id, :p_title, :p_release_date, :p_link, :p_pic_link); END;`,
      { p_musician_id: nummusicianId, p_title: title, p_release_date: orareleaseDate, p_link: link, p_pic_link: picLink }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/update-album', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    console.log(req.body);
    let { albumId, musicianId, title, releaseDate, link, picture } = req.body;
    albumId = Number(albumId);
    musicianId = Number(musicianId);
    releaseDate = new Date(releaseDate);
    console.log("PROBLEMO : " + albumId, musicianId, title, releaseDate, link, picture);
    await connection.execute(
      `BEGIN pkg_manager.update_album(:p_album_id, :p_musician_id, :p_title, :p_release_date, :p_link, :p_pic_link); END;`,
      { p_album_id: albumId, p_musician_id: musicianId, p_title: title, p_release_date: releaseDate, p_link: link, p_pic_link: picture }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/delete-album', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { albumId } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.delete_album(:p_album_id); END;`,
      { p_album_id: albumId }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.post('/api/update-award', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig.manager);
    const { awardId, awardName, awardDescription } = req.body;
    await connection.execute(
      `BEGIN pkg_manager.update_award(:p_award_id, :p_name, :p_description); END;`,
      { p_award_id: awardId, p_name: awardName, p_description: awardDescription }
    );
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      res.status(400).json({ error_code: Number(match[1]), message: match[2] });
    } else {
      res.status(500).json({ error: err.message });
    }
  } finally {
    if (connection) await connection.close();
  }
});

app.get('/api/get-tracks-by-album/:albumId', async (req, res) => {
  let connection;
  const albumId = Number(req.params.albumId); 
  try {
    connection = await oracledb.getConnection(dbConfig.guest);

    const result = await connection.execute(
      `BEGIN pkg_guest.get_tracks_by_album(:p_album_id, :p_cursor); END;`,
      {
        p_album_id: albumId,
        p_cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
      }
    );

    const cursor = result.outBinds.p_cursor;
    const rows = [];
    let row;
    while ((row = await cursor.getRow())) {
      rows.push(row);
    }
    await cursor.close();

    res.json(rows);

  } catch (err) {
    console.error("Oracle error full:", err);

    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      const code = Number(match[1]);
      const message = match[2];
      res.status(400).json({ error_code: code, message });
    } else {
      res.status(500).json({ error: err.message });
    }

  } finally {
    if (connection) await connection.close();
  }
});


app.get('/api/get-comments/:albumId', async (req, res) => {
  let connection;
  const albumId = Number(req.params.albumId);
  try {
    connection = await oracledb.getConnection(dbConfig.guest);
    const result = await connection.execute(
      `BEGIN pkg_guest.get_comments_by_album(:p_album_id, :p_cursor); END;`,
      {
        p_album_id: albumId, p_cursor: {dir:oracledb.BIND_OUT, type: oracledb.CURSOR}
      }
    )
    const cursor = result.outBinds.p_cursor;
    const rows = [];
    let row;
    while((row = await cursor.getRow())) {
      rows.push(row);
    }
    await cursor.close();
    res.json(rows);
  } catch (e){
    console.error(err);
    const match = err.message.match(/ORA-(\d+): (.+)/);
    if (match) {
      const code = Number(match[1]);
      const message = match[2];
      res.status(400).json({ error_code: code, message });
    } else {
      res.status(500).json({ error: err.message });
    }
  }finally {
    if (connection) await connection.close();
  }

});

app.get('/api/album/:albumId', async (req,res) => {
  let connection;
  const albumId = Number(req.params.albumId);
  try {
    connection = await oracledb.getConnection(dbConfig.guest);
    const result = await connection.execute(
      `BEGIN pkg_guest.get_album_description(:p_album_id, :p_cursor); END;`,
      {p_album_id: albumId, p_cursor: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR}}
    )
    const cursor = result.outBinds.p_cursor;
    const album = await cursor.getRow();
    await cursor.close();
    if (!album) {
      return res.status(404).json({ error: 'Album not found' });
    }
    res.json(album);
    
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }finally {
    if (connection) await connection.close();
  }
});


app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
