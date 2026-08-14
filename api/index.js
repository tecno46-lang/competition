const axios = require('axios');

module.exports = async (req, res) => {
    const { fileName, action, index, item } = req.body;
    
    // 1. گٹ ہب سے فائل کا موجودہ ڈیٹا حاصل کریں
    const apiUrl = `https://api.github.com/repos/${process.env.GITHUB_USER}/${process.env.GITHUB_REPO}/contents/${fileName}`;
    const headers = { 'Authorization': `Bearer ${process.env.GITHUB_TOKEN}` };

    const getRes = await axios.get(apiUrl, { headers });
    let content = JSON.parse(Buffer.from(getRes.data.content, 'base64').toString());

    // 2. ڈیٹا میں تبدیلی (Create/Edit/Delete)
    if (action === 'create') content.push(item);
    if (action === 'edit') content[index] = item;
    if (action === 'delete') content.splice(index, 1);

    // 3. گٹ ہب پر واپس اپلوڈ کریں
    const putData = {
        message: `${action} entry via Vercel`,
        content: Buffer.from(JSON.stringify(content, null, 2)).toString('base64'),
        sha: getRes.data.sha
    };

    await axios.put(apiUrl, putData, { headers });
    res.status(200).json({ success: true });
};