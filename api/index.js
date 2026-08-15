const { Octokit } = require("@octokit/rest");

module.exports = async (req, res) => {
    // CORS configuration
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    // Initialize GitHub API with token from environment variables
    const octokit = new Octokit({ auth: process.env.GITHUB_TOKEN });
    const owner = process.env.GITHUB_OWNER;
    const repo = process.env.GITHUB_REPO;

    // Get category from query (GET) or body (POST)
    const category = req.query.category || (req.body && req.body.category);
    if (!category) {
        return res.status(400).json({ error: "Category is required" });
    }

    const path = `${category}.json`;

    // ==================== READ FILE (GET) ====================
    if (req.method === 'GET') {
        try {
            const { data } = await octokit.repos.getContent({ owner, repo, path });
            const content = Buffer.from(data.content, 'base64').toString('utf8');
            return res.status(200).json({ sha: data.sha, data: JSON.parse(content) });
        } catch (error) {
            if (error.status === 404) {
                // If file does not exist, return empty array
                return res.status(200).json({ sha: null, data: [] });
            }
            return res.status(500).json({ error: error.message });
        }
    }

    // ==================== UPDATE/CREATE FILE (POST) ====================
    if (req.method === 'POST') {
        try {
            const { data: newContent, sha } = req.body;
            const encodedContent = Buffer.from(JSON.stringify(newContent, null, 2)).toString('base64');
            
            const params = {
                owner,
                repo,
                path,
                message: `Updated ${path} via API`,
                content: encodedContent,
            };
            if (sha) params.sha = sha; // Need SHA to update existing files

            const { data } = await octokit.repos.createOrUpdateFileContents(params);
            return res.status(200).json({ success: true, sha: data.content.sha });
        } catch (error) {
            return res.status(500).json({ error: error.message });
        }
    }

    return res.status(405).json({ error: "Method not allowed" });
};