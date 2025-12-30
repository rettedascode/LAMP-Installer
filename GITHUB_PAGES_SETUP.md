# GitHub Pages Setup Guide

Follow these steps to publish your LAMP installer script to GitHub Pages:

## Step 1: Create a GitHub Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the "+" icon in the top right and select "New repository"
3. Name it `LAMPInstaller` (or your preferred name)
4. Make it **public** (required for free GitHub Pages)
5. **Don't** initialize with README, .gitignore, or license (we already have files)
6. Click "Create repository"

## Step 2: Push Your Files to GitHub

Open a terminal in your project directory and run:

```bash
# Initialize git repository (if not already done)
git init

# Add all files
git add .

# Commit the files
git commit -m "Initial commit: LAMP installer with GitHub Pages"

# Add your GitHub repository as remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/LAMPInstaller.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. Click on **Settings** (top menu)
3. Scroll down to **Pages** in the left sidebar
4. Under **Source**, select:
   - **Branch**: `main` (or `master`)
   - **Folder**: `/ (root)`
5. Click **Save**

## Step 4: Update GitHub Link (Optional)

After your repository is set up, update the GitHub link in `index.html`:

1. Find line 228 in `index.html`
2. Replace `yourusername` with your actual GitHub username
3. Commit and push the change:
   ```bash
   git add index.html
   git commit -m "Update GitHub link"
   git push
   ```

## Step 5: Access Your Site

Your GitHub Pages site will be available at:
```
https://YOUR_USERNAME.github.io/LAMPInstaller/
```

**Note:** It may take a few minutes for the site to be available after enabling GitHub Pages.

## File Structure

Your repository should have:
```
LAMPInstaller/
├── installer.sh          # Your main installer script
├── index.html            # GitHub Pages landing page
├── README.md             # Repository documentation
├── .nojekyll             # Prevents Jekyll processing
└── GITHUB_PAGES_SETUP.md # This file
```

## Troubleshooting

### Site not loading?
- Wait 5-10 minutes after enabling GitHub Pages
- Check the **Actions** tab in your repository for build errors
- Ensure your repository is **public**

### Script not downloading?
- Make sure `installer.sh` is in the root directory
- Check that the file has proper line endings (LF, not CRLF)

### Want to use a custom domain?
- See GitHub's documentation on [custom domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)

## Next Steps

- Share your GitHub Pages URL with others
- The script can be downloaded directly from the page
- Users can view the script source before downloading
- Consider adding a license file to your repository

