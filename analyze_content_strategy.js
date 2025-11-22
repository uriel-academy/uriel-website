const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

class ContentStrategyAnalyzer {
  constructor() {
    this.metrics = {};
    this.recommendations = [];
  }

  async analyzeContentStrategy() {
    console.log('📊 Analyzing Content Strategy...\n');

    try {
      // Get all storybooks
      const storybooksSnapshot = await db.collection('storybooks').get();
      const storybooks = [];

      storybooksSnapshot.forEach(doc => {
        storybooks.push({
          id: doc.id,
          ...doc.data()
        });
      });

      console.log(`📚 Total Books: ${storybooks.length}`);
      console.log(`📖 Active Books: ${storybooks.filter(b => b.isActive).length}`);

      // Analyze download patterns
      await this.analyzeDownloadPatterns(storybooks);

      // Analyze categories
      await this.analyzeCategories(storybooks);

      // Generate recommendations
      await this.generateRecommendations(storybooks);

      // Create strategy report
      await this.createStrategyReport();

    } catch (error) {
      console.error('❌ Error analyzing content strategy:', error.message);
    }
  }

  async analyzeDownloadPatterns(storybooks) {
    console.log('\n📈 Download Pattern Analysis:');

    const activeBooks = storybooks.filter(b => b.isActive);
    const totalDownloads = activeBooks.reduce((sum, book) => sum + (book.downloadCount || 0), 0);
    const avgDownloads = totalDownloads / activeBooks.length;

    console.log(`   Total Downloads: ${totalDownloads}`);
    console.log(`   Average per Book: ${avgDownloads.toFixed(1)}`);

    // Books with no downloads
    const noDownloads = activeBooks.filter(b => (b.downloadCount || 0) === 0);
    console.log(`   Books with No Downloads: ${noDownloads.length}`);

    // Top performers
    const topPerformers = activeBooks
      .sort((a, b) => (b.downloadCount || 0) - (a.downloadCount || 0))
      .slice(0, 10);

    console.log('\n🏆 Top 10 Performing Books:');
    topPerformers.forEach((book, index) => {
      console.log(`   ${index + 1}. "${book.title}" by ${book.author} - ${book.downloadCount || 0} downloads`);
    });

    this.metrics.downloadPatterns = {
      totalDownloads,
      averageDownloads: avgDownloads,
      booksWithNoDownloads: noDownloads.length,
      topPerformers: topPerformers.map(b => ({
        title: b.title,
        author: b.author,
        downloads: b.downloadCount || 0
      }))
    };
  }

  async analyzeCategories(storybooks) {
    console.log('\n📂 Category Analysis:');

    const categoryStats = {};
    const activeBooks = storybooks.filter(b => b.isActive);

    activeBooks.forEach(book => {
      const category = book.category || 'uncategorized';
      if (!categoryStats[category]) {
        categoryStats[category] = {
          count: 0,
          downloads: 0,
          books: []
        };
      }
      categoryStats[category].count++;
      categoryStats[category].downloads += book.downloadCount || 0;
      categoryStats[category].books.push({
        title: book.title,
        downloads: book.downloadCount || 0
      });
    });

    // Sort categories by download count
    const sortedCategories = Object.entries(categoryStats)
      .sort(([,a], [,b]) => b.downloads - a.downloads);

    console.log('   Category Performance:');
    sortedCategories.forEach(([category, stats]) => {
      console.log(`   ${category}: ${stats.count} books, ${stats.downloads} downloads (${(stats.downloads / stats.count).toFixed(1)} avg)`);
    });

    this.metrics.categories = Object.fromEntries(sortedCategories);
  }

  async generateRecommendations(storybooks) {
    console.log('\n💡 Content Strategy Recommendations:');

    const recommendations = [];
    const activeBooks = storybooks.filter(b => b.isActive);

    // 1. Popular books to feature
    const popularBooks = activeBooks
      .sort((a, b) => (b.downloadCount || 0) - (a.downloadCount || 0))
      .slice(0, 5);

    recommendations.push({
      priority: 'high',
      type: 'homepage_feature',
      title: 'Feature Top 5 Books on Homepage',
      description: 'Prominently display the most downloaded books to increase engagement',
      books: popularBooks.map(b => b.title),
      impact: 'High - Immediate visibility boost'
    });

    // 2. Books needing promotion
    const booksNeedingPromotion = activeBooks
      .filter(b => (b.downloadCount || 0) === 0)
      .slice(0, 10);

    if (booksNeedingPromotion.length > 0) {
      recommendations.push({
        priority: 'medium',
        type: 'promotion_campaign',
        title: 'Promote Undiscovered Books',
        description: `Create campaigns for ${booksNeedingPromotion.length} books with zero downloads`,
        books: booksNeedingPromotion.map(b => b.title),
        impact: 'Medium - Long-term engagement growth'
      });
    }

    // 3. Category focus
    const categoryDownloads = {};
    activeBooks.forEach(book => {
      const category = book.category || 'uncategorized';
      categoryDownloads[category] = (categoryDownloads[category] || 0) + (book.downloadCount || 0);
    });

    const topCategory = Object.entries(categoryDownloads)
      .sort(([,a], [,b]) => b - a)[0];

    if (topCategory) {
      recommendations.push({
        priority: 'high',
        type: 'category_focus',
        title: `Focus on ${topCategory[0]} Category`,
        description: `Invest more in the highest-performing category (${topCategory[1]} downloads)`,
        impact: 'High - ROI optimization'
      });
    }

    // 4. User experience improvements
    recommendations.push({
      priority: 'high',
      type: 'ux_improvement',
      title: 'Implement Book Recommendations',
      description: 'Add personalized book recommendations based on reading history',
      impact: 'High - User engagement boost'
    });

    recommendations.push({
      priority: 'medium',
      type: 'analytics_enhancement',
      title: 'Enhanced Analytics Tracking',
      description: 'Track reading time, completion rates, and user preferences',
      impact: 'Medium - Better data-driven decisions'
    });

    // Display recommendations
    recommendations.forEach((rec, index) => {
      console.log(`\n${index + 1}. [${rec.priority.toUpperCase()}] ${rec.title}`);
      console.log(`   ${rec.description}`);
      console.log(`   Impact: ${rec.impact}`);
      if (rec.books && rec.books.length > 0) {
        console.log(`   Books: ${rec.books.slice(0, 3).join(', ')}${rec.books.length > 3 ? '...' : ''}`);
      }
    });

    this.recommendations = recommendations;
  }

  async createStrategyReport() {
    const report = {
      generatedAt: new Date().toISOString(),
      metrics: this.metrics,
      recommendations: this.recommendations,
      summary: {
        totalBooks: this.metrics.downloadPatterns?.topPerformers?.length || 0,
        totalDownloads: this.metrics.downloadPatterns?.totalDownloads || 0,
        topCategory: Object.keys(this.metrics.categories || {})[0],
        recommendationsCount: this.recommendations.length
      }
    };

    const filename = `content_strategy_report_${new Date().toISOString().split('T')[0]}.json`;
    fs.writeFileSync(filename, JSON.stringify(report, null, 2));

    console.log(`\n📄 Strategy report saved to: ${filename}`);
    console.log('\n✅ Content Strategy Analysis Complete!');
    console.log('🎯 Next Steps:');
    console.log('   1. Implement homepage book features');
    console.log('   2. Create promotion campaigns for undiscovered books');
    console.log('   3. Focus development on high-performing categories');
    console.log('   4. Add personalized recommendations');
    console.log('   5. Run this analysis monthly to track progress');
  }
}

// Run the analysis
const analyzer = new ContentStrategyAnalyzer();
analyzer.analyzeContentStrategy().catch(console.error);